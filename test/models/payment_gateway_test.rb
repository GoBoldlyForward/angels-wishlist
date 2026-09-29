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

  private

  def stripe_event(type, **object)
    Stripe::Event.construct_from(type: type, data: { object: object })
  end
end
