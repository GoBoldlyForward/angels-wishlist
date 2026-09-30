# frozen_string_literal: true

# Every call to Stripe goes through here. Without a secret key the gateway
# runs in test mode: nothing is charged or transferred, and each step
# succeeds at once so the whole program can be exercised end to end.
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

  def construct_event(payload, signature)
    Stripe::Webhook.construct_event(payload, signature, ENV.fetch("STRIPE_WEBHOOK_SECRET"))
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
          metadata: { household: household.id } },
        { api_key: ENV["STRIPE_SECRET_KEY"] }
      )
      household.update!(stripe_account_id: account.id)
    end

    Stripe::AccountLink.create(
      { account: household.stripe_account_id, type: "account_onboarding",
        return_url: return_url, refresh_url: refresh_url },
      { api_key: ENV["STRIPE_SECRET_KEY"] }
    ).url
  end

  # The account exists as soon as onboarding starts. It counts once the
  # caregiver has finished Stripe's form.
  def sync_onboarding(household)
    return if !live? || household.stripe_account_id.blank? || household.stripe_connected?

    account = Stripe::Account.retrieve(household.stripe_account_id, { api_key: ENV["STRIPE_SECRET_KEY"] })
    household.update!(stripe_onboarded_at: Time.current) if account.details_submitted
  end

  def transfer(payout)
    return payout.mark_sent!(stripe_transfer_id: "tr_test_#{SecureRandom.hex(6)}") unless live?

    transfer = Stripe::Transfer.create(
      { amount: payout.amount_in_cents, currency: "usd", destination: payout.household.stripe_account_id,
        description: "#{payout.event.name} wish list", metadata: { payout: payout.id } },
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
    lines << [ "Card processing", donation.fee_in_cents ] if donation.fee_in_cents.positive?

    lines.map do |name, cents|
      { quantity: 1, price_data: { currency: "usd", unit_amount: cents, product_data: { name: name } } }
    end
  end
end
