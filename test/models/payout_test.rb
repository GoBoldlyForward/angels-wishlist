# frozen_string_literal: true

require "test_helper"

class PayoutTest < ActiveSupport::TestCase
  setup do
    @household = build_household
    @event = build_event(organization: @household.organization)
    @wishlist = build_wishlist(child: build_child(household: @household), event: @event)
    build_line_item(wishlist: @wishlist, price_in_cents: 20_000)
    build_donation(event: @event, gift_in_cents: 0, general_gift_in_cents: 15_000)
  end

  test "a payout is the household's share of the pool" do
    payout = @event.build_payouts!.first

    assert_equal 15_000, payout.amount_in_cents
    assert payout.scheduled?
    assert payout.via_stripe?
    assert payout.payable?
  end

  test "building payouts twice keeps one payout per household" do
    @event.build_payouts!
    build_donation(event: @event, gift_in_cents: 0, general_gift_in_cents: 1_000)

    assert_no_difference -> { Payout.count } do
      assert_equal 16_000, @event.build_payouts!.first.amount_in_cents
    end
  end

  test "a payout already sent is left alone" do
    payout = @event.build_payouts!.first
    payout.mark_sent!(stripe_transfer_id: "tr_123")
    build_donation(event: @event, gift_in_cents: 0, general_gift_in_cents: 1_000)

    assert_equal 15_000, @event.build_payouts!.first.amount_in_cents
    assert_equal "tr_123", payout.reload.stripe_transfer_id
  end

  test "a household on hold is held with its share waiting" do
    @household.hold!("Placement change reported.")
    payout = @event.build_payouts!.first

    assert payout.held?
    assert_equal 15_000, payout.amount_in_cents
    assert_not payout.payable?
    assert_equal :hold, @household.payout_status(@event)
  end

  test "a household with no payout method is blocked" do
    @household.update!(payout_method: "none")
    payout = @event.build_payouts!.first

    assert payout.blocked?
    assert_nil payout.method
    assert_equal "No payout method on file.", payout.blocker
    assert_equal :nomethod, @household.payout_status(@event)
  end

  test "a gift card needs somewhere to go" do
    @household.update!(payout_method: "gift_card")

    assert_equal "No email address for the gift card.", @household.payout_blocker

    @household.update!(gift_card_email: "cards@example.com")
    assert_nil @household.payout_blocker
    assert_equal "cards@example.com", @event.build_payouts!.first.destination
  end

  test "one payout per household per event" do
    Payout.create!(household: @household, event: @event, amount_in_cents: 6_000)
    duplicate = Payout.new(household: @household, event: @event, amount_in_cents: 6_000)

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end
end
