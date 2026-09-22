# frozen_string_literal: true

require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "phase is read from the dates, not stored" do
    assert_equal :draft, build_event(opened_at: 1.day.from_now).phase
    assert_equal :open, build_event(opened_at: 1.day.ago, closes_at: 1.day.from_now).phase
    assert_equal :closed,
                 build_event(opened_at: 2.weeks.ago, closes_at: 1.day.ago, payout_at: 1.day.from_now).phase
    assert_equal :paid_out,
                 build_event(opened_at: 3.weeks.ago, closes_at: 2.days.ago, payout_at: 1.day.ago).phase
  end

  test "days remaining never goes negative" do
    assert_equal 0, build_event(opened_at: 3.weeks.ago, closes_at: 1.day.ago).days_remaining
  end

  test "goal and raised roll up from the lines" do
    event = build_event
    wishlist = build_wishlist(event: event)
    build_line_item(wishlist: wishlist, price_in_cents: 4_800)
    funded = build_line_item(wishlist: wishlist, price_in_cents: 6_000)
    funded.fund!(build_donation(event: event, gift_in_cents: 6_000))

    assert_equal 10_800, event.goal_in_cents
    assert_equal 6_000, event.raised_in_cents
    assert_equal 56, event.percent_funded
  end

  test "general giving counts toward raised but not toward the goal" do
    event = build_event
    wishlist = build_wishlist(event: event)
    build_line_item(wishlist: wishlist, price_in_cents: 4_800)
    build_donation(event: event, gift_in_cents: 0, general_gift_in_cents: 10_000)

    assert_equal 4_800, event.goal_in_cents
    assert_equal 10_000, event.raised_in_cents
  end

  test "closing before opening is rejected" do
    event = Event.new(organization: build_organization, name: "Backwards",
                      opened_at: 1.day.from_now, closes_at: 1.day.ago)

    assert_not event.valid?
    assert_includes event.errors[:closes_at].first, "after the event opens"
  end
end
