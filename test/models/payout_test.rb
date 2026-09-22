# frozen_string_literal: true

require "test_helper"

class PayoutTest < ActiveSupport::TestCase
  setup do
    @household = build_household
    @event = build_event(organization: @household.organization)
    @wishlist = build_wishlist(child: build_child(household: @household), event: @event)
    line = build_line_item(wishlist: @wishlist, price_in_cents: 6_000)
    line.fund!(build_donation(event: @event, gift_in_cents: 6_000))
  end

  test "a payout matching what the lists raised is not an override" do
    payout = Payout.create!(household: @household, event: @event, amount_in_cents: 6_000)

    assert_equal 6_000, payout.raised_in_cents
    assert_not payout.overridden?
    assert_equal 0, payout.top_up_in_cents
  end

  test "overriding the amount requires a note saying why" do
    payout = Payout.new(household: @household, event: @event, amount_in_cents: 10_000)

    assert_not payout.valid?
    assert_includes payout.errors.attribute_names, :adjustment_note
  end

  test "a top up draws the difference from general giving" do
    payout = Payout.create!(household: @household, event: @event, amount_in_cents: 10_000,
                            adjustment_note: "Topped up from general giving.")

    assert payout.overridden?
    assert_equal 4_000, payout.top_up_in_cents
  end

  test "an unapplied pool shrinks by what top ups have spent" do
    build_donation(event: @event, gift_in_cents: 0, general_gift_in_cents: 10_000)
    assert_equal 10_000, @event.unapplied_general_giving_in_cents

    Payout.create!(household: @household, event: @event, amount_in_cents: 10_000,
                   adjustment_note: "Topped up from general giving.")

    assert_equal 6_000, @event.reload.unapplied_general_giving_in_cents
  end

  test "a household on hold cannot be paid" do
    @household.update!(verification_status: "hold", hold_reason: "Placement change reported.")
    payout = Payout.create!(household: @household, event: @event, amount_in_cents: 6_000,
                            status: "scheduled")

    assert_not payout.payable?
    assert_equal :hold, @household.payout_status(@event)
  end

  test "a household with no payout method cannot be paid" do
    @household.update!(payout_method: "none")

    assert_not @household.payable?
    assert_equal :nomethod, @household.payout_status(@event)
  end

  test "one payout per household per event" do
    Payout.create!(household: @household, event: @event, amount_in_cents: 6_000)
    duplicate = Payout.new(household: @household, event: @event, amount_in_cents: 6_000)

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end
end
