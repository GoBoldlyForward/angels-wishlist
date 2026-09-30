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
  # confirmation page, with the donation already settled. A live donation is a
  # destination charge: it lands in the chapter's account, less the application fee.
  def start_checkout(donation, success_url:, cancel_url:)
    unless live?
      donation.update!(payment_method_label: "Test mode")
      donation.settle!
      return Checkout.new(url: success_url, reference: nil)
    end

    chapter_account = donation.event.organization.stripe_account_id
    session = Stripe::Checkout::Session.create(
      { mode: "payment", customer_email: donation.donor.email, client_reference_id: donation.uuid,
        success_url: success_url, cancel_url: cancel_url, line_items: checkout_lines(donation),
        payment_intent_data: { metadata: { donation: donation.uuid },
                               description: "Donation to the holiday wish list program",
                               on_behalf_of: chapter_account, transfer_data: { destination: chapter_account },
                               application_fee_amount: donation.application_fee_in_cents },
        submit_type: "donate" },
      { api_key: ENV["STRIPE_SECRET_KEY"], idempotency_key: "checkout-#{donation.uuid}" }
    )
    Checkout.new(url: session.url, reference: session.id)
  end

  # The platform's own events and its connected accounts' events arrive signed with different secrets.
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
      Organization.chapter.find_by(stripe_account_id: object.id)&.update!(stripe_charges_enabled: object.charges_enabled)
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

  # A destination charge gives back the chapter's share and the application fee along with the donor's money.
  def refund(donation)
    if live? && donation.stripe_payment_intent_id.present?
      returned = donation.application_fee_in_cents.positive? ? { reverse_transfer: true, refund_application_fee: true } : {}
      Stripe::Refund.create({ payment_intent: donation.stripe_payment_intent_id, **returned },
                            { api_key: ENV["STRIPE_SECRET_KEY"], idempotency_key: "refund-#{donation.uuid}" })
    end
    donation.refund!
  end

  # A chapter takes donations into its own Express account. Payouts stay manual so the
  # balance is still there when caregivers are paid from it.
  def chapter_onboarding_url(chapter, return_url:, refresh_url:)
    unless live?
      chapter.update!(stripe_account_id: "acct_test_#{SecureRandom.hex(6)}", stripe_charges_enabled: true)
      return return_url
    end

    if chapter.stripe_account_id.blank?
      account = Stripe::Account.create(
        { type: "express", country: "US", business_type: "non_profit",
          business_profile: { name: chapter.legal_name_or_name, url: chapter.website_url.presence }.compact,
          capabilities: { card_payments: { requested: true }, transfers: { requested: true } },
          settings: { payouts: { schedule: { interval: "manual" } } },
          metadata: { organization: chapter.id } },
        { api_key: ENV["STRIPE_SECRET_KEY"], idempotency_key: "chapter-account-#{chapter.id}" }
      )
      chapter.update!(stripe_account_id: account.id)
    end

    account_link(chapter.stripe_account_id, return_url:, refresh_url:)
  end

  def refresh_chapter(chapter)
    return chapter if !live? || chapter.stripe_account_id.blank?

    account = Stripe::Account.retrieve(chapter.stripe_account_id, { api_key: ENV["STRIPE_SECRET_KEY"] })
    chapter.update!(stripe_charges_enabled: account.charges_enabled)
    chapter
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

    account_link(household.stripe_account_id, return_url:, refresh_url:)
  end

  def account_link(account_id, return_url:, refresh_url:)
    Stripe::AccountLink.create(
      { account: account_id, type: "account_onboarding", return_url: return_url, refresh_url: refresh_url },
      { api_key: ENV["STRIPE_SECRET_KEY"] }
    ).url
  end

  # What the chapter could send to its bank today. Test mode has no balance to read.
  def chapter_balance_in_cents(chapter)
    return nil if !live? || chapter.stripe_account_id.blank?

    balance = Stripe::Balance.retrieve({ api_key: ENV["STRIPE_SECRET_KEY"], stripe_account: chapter.stripe_account_id })
    balance.available.select { |funds| funds.currency == "usd" }.sum(&:amount)
  end

  def release_to_bank(chapter, cents)
    return unless live?

    Stripe::Payout.create({ amount: cents, currency: "usd", description: "Wish List funds" },
                          { api_key: ENV["STRIPE_SECRET_KEY"], stripe_account: chapter.stripe_account_id })
  end

  # The account exists as soon as onboarding starts. It counts once the
  # caregiver has finished Stripe's form.
  def sync_onboarding(household)
    return if !live? || household.stripe_account_id.blank? || household.stripe_connected?

    account = Stripe::Account.retrieve(household.stripe_account_id, { api_key: ENV["STRIPE_SECRET_KEY"] })
    household.update!(stripe_onboarded_at: Time.current) if account.details_submitted
  end

  # The share comes out of the chapter's balance by account debit, then goes to the caregiver
  # from the platform's, since only the platform can transfer to a caregiver's account.
  def transfer(payout)
    return payout.mark_sent!(stripe_transfer_id: "tr_test_#{SecureRandom.hex(6)}") unless live?

    debit_chapter(payout)
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

  # A retried payout reuses its debit. One whose amount changed since gives the old debit back first.
  def debit_chapter(payout)
    return if payout.debited_in_cents == payout.amount_in_cents

    if payout.stripe_debit_id.present?
      Stripe::Refund.create({ charge: payout.stripe_debit_id },
                            { api_key: ENV["STRIPE_SECRET_KEY"], idempotency_key: "undebit-#{payout.stripe_debit_id}" })
      payout.update!(stripe_debit_id: nil, debited_in_cents: nil)
    end

    debit = Stripe::Charge.create(
      { amount: payout.amount_in_cents, currency: "usd", source: payout.event.organization.stripe_account_id,
        description: "#{payout.event.name} payout to #{payout.household.display_name}",
        metadata: { payout: payout.id } },
      { api_key: ENV["STRIPE_SECRET_KEY"], idempotency_key: "debit-#{payout.id}-#{payout.amount_in_cents}" }
    )
    payout.update!(stripe_debit_id: debit.id, debited_in_cents: payout.amount_in_cents)
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
