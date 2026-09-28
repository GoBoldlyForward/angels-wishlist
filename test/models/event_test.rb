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

  test "the goal is what the counted lists ask for" do
    event = build_event
    build_line_item(wishlist: build_wishlist(event: event), price_in_cents: 4_800)
    build_line_item(wishlist: build_wishlist(event: event, status: "draft"), price_in_cents: 6_000)

    assert_equal 4_800, event.goal_in_cents
  end

  test "raised is every succeeded gift, chosen or general" do
    event = build_event
    build_line_item(wishlist: build_wishlist(event: event), price_in_cents: 10_000)
    build_donation(event: event, gift_in_cents: 4_000, general_gift_in_cents: 1_000, fee_in_cents: 150)
    build_donation(event: event, gift_in_cents: 9_000, status: "refunded")

    assert_equal 5_000, event.raised_in_cents
    assert_equal 50, event.percent_funded
  end

  test "every list is funded to the same percentage" do
    event = build_event
    small = build_wishlist(event: event)
    large = build_wishlist(event: event)
    build_line_item(wishlist: small, price_in_cents: 10_000)
    build_line_item(wishlist: large, price_in_cents: 20_000)
    build_donation(event: event, gift_in_cents: 0, general_gift_in_cents: 22_500)

    assert_equal Rational(3, 4), event.funded_ratio
    assert_equal 7_500, small.share_in_cents
    assert_equal 15_000, large.share_in_cents
  end

  test "which gifts donors chose does not change a share" do
    event = build_event
    chosen = build_wishlist(event: event)
    skipped = build_wishlist(event: event)
    line = build_line_item(wishlist: chosen, price_in_cents: 10_000)
    build_line_item(wishlist: skipped, price_in_cents: 10_000)
    line.fund!(build_donation(event: event, gift_in_cents: 10_000))

    assert_equal 5_000, chosen.share_in_cents
    assert_equal 5_000, skipped.share_in_cents
  end

  test "shares add up to the pool to the cent" do
    event = build_event
    3.times { build_line_item(wishlist: build_wishlist(event: event), price_in_cents: 10_000) }
    build_donation(event: event, gift_in_cents: 0, general_gift_in_cents: 10_000)

    assert_equal [ 3_333, 3_333, 3_334 ], event.shares.values.sort
    assert_equal 10_000, event.shares.values.sum
  end

  test "a withdrawn list leaves the total and its share moves to the others" do
    event = build_event
    staying = build_wishlist(event: event)
    leaving = build_wishlist(event: event)
    build_line_item(wishlist: staying, price_in_cents: 10_000)
    build_line_item(wishlist: leaving, price_in_cents: 10_000)
    build_donation(event: event, gift_in_cents: 0, general_gift_in_cents: 10_000)
    assert_equal 5_000, staying.share_in_cents

    leaving.withdraw!

    assert_equal 10_000, event.reload.share_for(staying)
    assert_equal 0, event.share_for(leaving)
  end

  test "a list is never funded past what it asked for" do
    event = build_event
    wishlist = build_wishlist(event: event)
    build_line_item(wishlist: wishlist, price_in_cents: 10_000)
    build_donation(event: event, gift_in_cents: 0, general_gift_in_cents: 25_000)

    assert_equal 1, event.funded_ratio
    assert_equal 10_000, wishlist.share_in_cents
    assert_equal 15_000, event.surplus_in_cents
  end

  test "a household's share is the sum of its children's lists" do
    household = build_household
    event = build_event(organization: household.organization)
    2.times do
      build_line_item(wishlist: build_wishlist(child: build_child(household: household), event: event),
                      price_in_cents: 10_000)
    end
    build_line_item(wishlist: build_wishlist(event: event), price_in_cents: 20_000)
    build_donation(event: event, gift_in_cents: 0, general_gift_in_cents: 20_000)

    assert_equal 10_000, household.share_in_cents(event)
  end

  test "an unverified household's list is not counted" do
    event = build_event
    pending = build_household(verification_status: "pending")
    build_line_item(wishlist: build_wishlist(child: build_child(household: pending), event: event),
                    price_in_cents: 10_000)

    assert_equal 0, event.goal_in_cents
  end

  test "closing before opening is rejected" do
    event = Event.new(organization: build_organization, name: "Backwards",
                      opened_at: 1.day.from_now, closes_at: 1.day.ago)

    assert_not event.valid?
    assert_includes event.errors[:closes_at].first, "after the event opens"
  end
end
