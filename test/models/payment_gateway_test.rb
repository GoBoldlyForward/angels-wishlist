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

  private

  def stripe_event(type, **object)
    Stripe::Event.construct_from(type: type, data: { object: object })
  end
end
