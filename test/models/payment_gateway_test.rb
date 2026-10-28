# frozen_string_literal: true

require "test_helper"

class PaymentGatewayTest < ActiveSupport::TestCase
  test "a live donation is charged straight into the chapter's account" do
    donation = build_donation(event: build_event, status: "pending", gift_in_cents: 0,
                              general_gift_in_cents: 10_000, fee_in_cents: 330, processing_fee_in_cents: 330)
    sent = nil
    create = ->(params, _options) { sent = params; Stripe::Checkout::Session.construct_from(id: "cs_1", url: "https://pay.test") }

    swapping(PaymentGateway, :live?, -> { true }) do
      swapping(Stripe::Checkout::Session, :create, create) do
        PaymentGateway.start_checkout(donation, success_url: "https://s.test", cancel_url: "https://c.test")
      end
    end

    assert_equal %i[metadata description], sent[:payment_intent_data].keys
    assert_equal 10_330, sent[:line_items].sum { |line| line.dig(:price_data, :unit_amount) }
  end

  test "refunding a donation is a plain refund of its payment" do
    donation = build_donation(event: build_event, stripe_payment_intent_id: "pi_1", processing_fee_in_cents: 174)
    sent = nil

    swapping(PaymentGateway, :live?, -> { true }) do
      swapping(Stripe::Refund, :create, ->(params, _options) { sent = params }) { PaymentGateway.refund(donation) }
    end

    assert_equal({ payment_intent: "pi_1" }, sent)
    assert donation.reload.refunded?
  end

  test "a payout is one transfer from the chapter's balance to the caregiver" do
    calls = []
    payout = stripe_payout(amount_in_cents: 12_000)

    live_stripe(calls) { PaymentGateway.transfer(payout) }

    assert_equal [ [ :transfer, 12_000, "acct_caregiver" ] ], calls
    payout.reload
    assert payout.sent?
    assert_equal "tr_1", payout.stripe_transfer_id
  end

  test "a transfer Stripe refuses marks the payout failed with the reason, and it can be retried" do
    calls = []
    payout = stripe_payout(amount_in_cents: 12_000)

    live_stripe(calls, transfer: ->(*) { raise Stripe::InvalidRequestError.new("Insufficient funds", nil) }) do
      PaymentGateway.transfer(payout)
    end
    assert payout.reload.failed?
    assert_equal "Insufficient funds", payout.hold_reason

    live_stripe(calls) { PaymentGateway.transfer(payout) }

    assert payout.reload.sent?
  end

  test "a caregiver's account.updated event marks the household onboarded once Stripe has its details" do
    household = build_household(stripe_account_id: "acct_caregiver", stripe_onboarded_at: nil)

    PaymentGateway.handle(stripe_event("account.updated", id: "acct_caregiver", details_submitted: false))
    assert_not household.reload.stripe_connected?

    PaymentGateway.handle(stripe_event("account.updated", id: "acct_caregiver", details_submitted: true))
    assert household.reload.stripe_connected?
  end

  test "an account.updated event for an account nobody holds is ignored" do
    household = build_household(stripe_account_id: "acct_caregiver", stripe_onboarded_at: nil)

    PaymentGateway.handle(stripe_event("account.updated", id: "acct_other", details_submitted: true))

    assert_not household.reload.stripe_connected?
  end

  private

  def stripe_payout(**attributes)
    chapter = build_organization
    household = build_household(organization: chapter, stripe_account_id: "acct_caregiver")
    Payout.create!({ household: household, event: build_event(organization: chapter), status: "scheduled",
                     method: "stripe" }.merge(attributes))
  end

  def live_stripe(calls, transfer: nil)
    transfer ||= lambda do |params, _options|
      calls << [ :transfer, params[:amount], params[:destination] ]
      Stripe::Transfer.construct_from(id: "tr_1")
    end

    swapping(PaymentGateway, :live?, -> { true }) do
      swapping(Stripe::Transfer, :create, transfer) { yield }
    end
  end

  def stripe_event(type, **object)
    Stripe::Event.construct_from(type: type, data: { object: object })
  end
end
