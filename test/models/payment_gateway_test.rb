# frozen_string_literal: true

require "test_helper"

class PaymentGatewayTest < ActiveSupport::TestCase
  test "an account.updated event records whether the chapter can take charges" do
    chapter = build_organization(stripe_account_id: "acct_chapter")

    PaymentGateway.handle(stripe_event("account.updated", id: "acct_chapter", charges_enabled: true))
    assert chapter.reload.stripe_charges_enabled?

    PaymentGateway.handle(stripe_event("account.updated", id: "acct_chapter", charges_enabled: false))
    assert_not chapter.reload.stripe_charges_enabled?
  end

  test "a caregiver's account.updated event leaves every chapter alone" do
    chapter = build_organization(stripe_account_id: "acct_chapter")

    PaymentGateway.handle(stripe_event("account.updated", id: "acct_caregiver", charges_enabled: true))

    assert_not chapter.reload.stripe_charges_enabled?
  end

  test "a live donation is a destination charge to the chapter, less the application fee" do
    chapter = build_organization(stripe_account_id: "acct_chapter", stripe_charges_enabled: true)
    donation = build_donation(event: build_event(organization: chapter), status: "pending", gift_in_cents: 0,
                              general_gift_in_cents: 10_000, fee_in_cents: 844,
                              platform_fee_in_cents: 500, processing_fee_in_cents: 344)
    sent = nil
    create = ->(params, _options) { sent = params; Stripe::Checkout::Session.construct_from(id: "cs_1", url: "https://pay.test") }

    swapping(PaymentGateway, :live?, -> { true }) do
      swapping(Stripe::Checkout::Session, :create, create) do
        PaymentGateway.start_checkout(donation, success_url: "https://s.test", cancel_url: "https://c.test")
      end
    end

    intent = sent[:payment_intent_data]
    assert_equal [ "acct_chapter", "acct_chapter", 844 ],
                 [ intent[:on_behalf_of], intent.dig(:transfer_data, :destination), intent[:application_fee_amount] ]
    assert_equal 10_844, sent[:line_items].sum { |line| line.dig(:price_data, :unit_amount) }
  end

  test "refunding a destination charge takes back the chapter's share and the application fee" do
    donation = build_donation(event: build_event, stripe_payment_intent_id: "pi_1", processing_fee_in_cents: 174)
    sent = nil

    swapping(PaymentGateway, :live?, -> { true }) do
      swapping(Stripe::Refund, :create, ->(params, _options) { sent = params }) { PaymentGateway.refund(donation) }
    end

    assert_equal({ payment_intent: "pi_1", reverse_transfer: true, refund_application_fee: true }, sent)
    assert donation.reload.refunded?
  end

  test "a payout debits the chapter's balance, then transfers the share to the caregiver" do
    calls = []
    payout = stripe_payout(amount_in_cents: 12_000)

    live_stripe(calls) { PaymentGateway.transfer(payout) }

    assert_equal [ [ :debit, 12_000, "acct_chapter" ], [ :transfer, 12_000, "acct_caregiver" ] ], calls
    payout.reload
    assert payout.sent?
    assert_equal [ "py_1", 12_000, "tr_1" ], [ payout.stripe_debit_id, payout.debited_in_cents, payout.stripe_transfer_id ]
  end

  test "a payout retried after its transfer failed never debits the chapter twice" do
    calls = []
    payout = stripe_payout(amount_in_cents: 12_000)

    live_stripe(calls, transfer: ->(*) { raise Stripe::InvalidRequestError.new("Insufficient funds", nil) }) do
      PaymentGateway.transfer(payout)
    end
    assert payout.reload.failed?
    assert_equal "py_1", payout.stripe_debit_id

    calls.clear
    live_stripe(calls) { PaymentGateway.transfer(payout) }

    assert_equal [ [ :transfer, 12_000, "acct_caregiver" ] ], calls
    assert payout.reload.sent?
  end

  test "a payout whose amount changed since its debit gives the old debit back first" do
    calls = []
    payout = stripe_payout(amount_in_cents: 11_500, stripe_debit_id: "py_old", debited_in_cents: 12_000)

    live_stripe(calls) { PaymentGateway.transfer(payout) }

    assert_equal [ [ :undebit, "py_old" ], [ :debit, 11_500, "acct_chapter" ], [ :transfer, 11_500, "acct_caregiver" ] ], calls
    assert_equal [ "py_1", 11_500 ], [ payout.reload.stripe_debit_id, payout.debited_in_cents ]
  end

  private

  def stripe_payout(**attributes)
    chapter = build_organization(stripe_account_id: "acct_chapter", stripe_charges_enabled: true)
    household = build_household(organization: chapter, stripe_account_id: "acct_caregiver")
    Payout.create!({ household: household, event: build_event(organization: chapter), status: "scheduled",
                     method: "stripe" }.merge(attributes))
  end

  def live_stripe(calls, transfer: nil)
    debit = ->(params, _options) { calls << [ :debit, params[:amount], params[:source] ]; Stripe::Charge.construct_from(id: "py_1") }
    undebit = ->(params, _options) { calls << [ :undebit, params[:charge] ] }
    transfer ||= lambda do |params, _options|
      calls << [ :transfer, params[:amount], params[:destination] ]
      Stripe::Transfer.construct_from(id: "tr_1")
    end

    swapping(PaymentGateway, :live?, -> { true }) do
      swapping(Stripe::Charge, :create, debit) do
        swapping(Stripe::Refund, :create, undebit) do
          swapping(Stripe::Transfer, :create, transfer) { yield }
        end
      end
    end
  end

  def stripe_event(type, **object)
    Stripe::Event.construct_from(type: type, data: { object: object })
  end
end
