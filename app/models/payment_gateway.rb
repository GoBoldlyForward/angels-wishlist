# frozen_string_literal: true

# Every call to Stripe goes through here, against the chapter's own account. Without a secret
# key it runs in test mode: nothing moves, and each step succeeds at once.
module PaymentGateway
  Checkout = Data.define(:url, :reference)

  module_function

  def live?
    ENV["STRIPE_SECRET_KEY"].present?
  end

  # Where to send the donor to pay. In test mode that is straight to the
  # confirmation page, with the donation already settled.
  def start_checkout(donation, success_url:, cancel_url:)
    unless live?
      donation.update!(payment_method_label: "Test mode")
      donation.settle!
      return Checkout.new(url: success_url, reference: nil)
    end

    session = Stripe::Checkout::Session.create(
      { mode: "payment", customer_email: donation.donor.email, client_reference_id: donation.uuid,
        success_url: success_url, cancel_url: cancel_url, line_items: checkout_lines(donation),
        payment_intent_data: { metadata: { donation: donation.uuid },
                               description: "Donation to the holiday wish list program" },
        submit_type: "donate" },
      { api_key: ENV["STRIPE_SECRET_KEY"], idempotency_key: "checkout-#{donation.uuid}" }
    )
    Checkout.new(url: session.url, reference: session.id)
  end

  # The account's own events and its connected accounts' events arrive signed with different secrets.
  def construct_event(payload, signature)
    secrets = ENV.values_at("STRIPE_WEBHOOK_SECRET", "STRIPE_CONNECT_WEBHOOK_SECRET").compact_blank
    secrets.each_with_index do |secret, index|
      return Stripe::Webhook.construct_event(payload, signature, secret)
    rescue Stripe::SignatureVerificationError
      raise if index == secrets.size - 1
    end
    raise Stripe::SignatureVerificationError.new("No webhook secret is set", signature)
  end

  def handle(event)
    object = event.data.object

    case event.type
    when "checkout.session.completed", "checkout.session.async_payment_succeeded"
      settle(object) if object.payment_status == "paid"
    when "checkout.session.async_payment_failed", "checkout.session.expired"
      Donation.pending.find_by(uuid: object.client_reference_id)&.update!(status: "failed")
    when "charge.refunded"
      Donation.succeeded.find_by(stripe_payment_intent_id: object.payment_intent)&.refund!
    when "charge.dispute.created"
      Donation.succeeded.find_by(stripe_payment_intent_id: object.payment_intent)&.mark_disputed!
    when "account.updated"
      household = Household.find_by(stripe_account_id: object.id)
      record_onboarding(household, object) if household
    end
  end

  # Settles from the donor's return as well as the webhook, whichever
  # arrives first. Donation#settle! makes the second one a no-op.
  def confirm(donation, session_id)
    return donation unless live? && donation.pending? && session_id.present?

    session = Stripe::Checkout::Session.retrieve(session_id, { api_key: ENV["STRIPE_SECRET_KEY"] })
    settle(session) if session.client_reference_id == donation.uuid && session.payment_status == "paid"
    donation.reload
  end

  def refund(donation)
    if live? && donation.stripe_payment_intent_id.present?
      Stripe::Refund.create({ payment_intent: donation.stripe_payment_intent_id },
                            { api_key: ENV["STRIPE_SECRET_KEY"], idempotency_key: "refund-#{donation.uuid}" })
    end
    donation.refund!
  end

  # Stripe's own hosted onboarding, so identity and account details never
  # touch this application.
  def onboarding_url(household, return_url:, refresh_url:)
    unless live?
      household.update!(stripe_account_id: "acct_test_#{SecureRandom.hex(6)}", stripe_onboarded_at: Time.current)
      return return_url
    end

    if household.stripe_account_id.blank?
      account = Stripe::Account.create(
        { type: "express", country: "US", email: household.caregiver.email,
          capabilities: { transfers: { requested: true } }, business_type: "individual",
          metadata: { household: household.id, organization: household.organization_id } },
        { api_key: ENV["STRIPE_SECRET_KEY"] }
      )
      household.update!(stripe_account_id: account.id)
    end

    Stripe::AccountLink.create(
      { account: household.stripe_account_id, type: "account_onboarding", return_url: return_url, refresh_url: refresh_url },
      { api_key: ENV["STRIPE_SECRET_KEY"] }
    ).url
  end

  # The account exists as soon as onboarding starts. It counts once the
  # caregiver has finished Stripe's form.
  def sync_onboarding(household)
    return if !live? || household.stripe_account_id.blank? || household.stripe_connected?

    record_onboarding(household, Stripe::Account.retrieve(household.stripe_account_id, { api_key: ENV["STRIPE_SECRET_KEY"] }))
  end

  def record_onboarding(household, account)
    household.update!(stripe_onboarded_at: Time.current) if account.details_submitted && !household.stripe_connected?
  end

  # What the chapter could send to its bank today. Test mode has no balance to read.
  def balance_in_cents
    return nil unless live?

    balance = Stripe::Balance.retrieve({ api_key: ENV["STRIPE_SECRET_KEY"] })
    balance.available.select { |funds| funds.currency == "usd" }.sum(&:amount)
  end

  def release_to_bank(cents)
    return unless live?

    Stripe::Payout.create({ amount: cents, currency: "usd", description: "Wish List funds" },
                          { api_key: ENV["STRIPE_SECRET_KEY"] })
  end

  # The share goes from the chapter's balance to the caregiver's connected account.
  def transfer(payout)
    return payout.mark_sent!(stripe_transfer_id: "tr_test_#{SecureRandom.hex(6)}") unless live?

    transfer = Stripe::Transfer.create(
      { amount: payout.amount_in_cents, currency: "usd", destination: payout.household.stripe_account_id,
        transfer_group: "event-#{payout.event_id}", description: "#{payout.event.name} wish list",
        metadata: { payout: payout.id, organization: payout.event.organization_id } },
      { api_key: ENV["STRIPE_SECRET_KEY"], idempotency_key: "payout-#{payout.id}-#{payout.amount_in_cents}" }
    )
    payout.mark_sent!(stripe_transfer_id: transfer.id)
  rescue Stripe::StripeError => e
    payout.mark_failed!(e.message)
  end

  def settle(session)
    donation = Donation.find_by(uuid: session.client_reference_id)
    return if donation.nil? || donation.succeeded?

    donation.update!(stripe_payment_intent_id: session.payment_intent, payment_method_label: "Card")
    donation.settle!
    DonorMailer.receipt(donation).deliver_later
  end

  def checkout_lines(donation)
    lines = donation.chosen_line_items.map { |line| [ line.name, line.price_in_cents ] }
    lines << [ "Where it is needed most", donation.general_gift_in_cents ] if donation.general_gift_in_cents.positive?
    lines << [ "Card processing and fees", donation.fee_in_cents ] if donation.fee_in_cents.positive?

    lines.map do |name, cents|
      { quantity: 1, price_data: { currency: "usd", unit_amount: cents, product_data: { name: name } } }
    end
  end
end
