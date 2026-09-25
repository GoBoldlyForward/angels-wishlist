# frozen_string_literal: true

require "test_helper"

class WishlistTest < ActiveSupport::TestCase
  test "asked, raised, and remaining are sums over the lines" do
    wishlist = build_wishlist
    build_line_item(wishlist: wishlist, price_in_cents: 4_800)
    funded = build_line_item(wishlist: wishlist, price_in_cents: 6_000)
    funded.fund!(build_donation(event: wishlist.event, gift_in_cents: 6_000))

    assert_equal 10_800, wishlist.asked_in_cents
    assert_equal 6_000, wishlist.raised_in_cents
    assert_equal 4_800, wishlist.remaining_in_cents
    assert_equal 56, wishlist.percent_funded
  end

  test "an empty list is zero percent funded rather than a division error" do
    assert_equal 0, build_wishlist.percent_funded
  end

  test "a list may exceed the per-child cap" do
    event = build_event(per_child_cap_in_cents: 30_000)
    wishlist = build_wishlist(event: event)
    build_line_item(wishlist: wishlist, price_in_cents: 35_000)

    assert wishlist.over_cap?
    assert wishlist.valid?, "the cap warns, it does not block"
  end

  test "editing a live list sends it back for review" do
    wishlist = build_wishlist(status: "live", approved_at: Time.current)
    wishlist.update!(caregiver_note: "She started cooking dinner on Sundays.")

    assert_equal "in_review", wishlist.reload.status
    assert_nil wishlist.approved_at
  end

  test "approving a list publishes it" do
    wishlist = build_wishlist(status: "in_review")
    wishlist.approve!

    assert_equal "live", wishlist.reload.status
    assert_not_nil wishlist.approved_at
  end

  test "a list is fully funded only once every line is covered" do
    wishlist = build_wishlist
    line = build_line_item(wishlist: wishlist)
    assert_not wishlist.fully_funded?

    line.fund!(build_donation(event: wishlist.event))
    assert wishlist.reload.fully_funded?
  end

  test "a list is not shoppable once its event closes" do
    event = build_event(opened_at: 8.weeks.ago, closes_at: 1.week.ago, payout_at: 1.day.from_now)
    assert_not build_wishlist(event: event, status: "live").shoppable?
  end

  test "one list per child per event" do
    wishlist = build_wishlist
    duplicate = Wishlist.new(child: wishlist.child, event: wishlist.event)

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end
  test "editing a live list records who edited it and what changed" do
    wishlist = build_wishlist(status: "live", approved_at: Time.current, caregiver_note: "She loves to draw.")
    caregiver = wishlist.household.caregiver

    PaperTrail.request(whodunnit: caregiver.id) do
      wishlist.update!(caregiver_note: "She started cooking dinner on Sundays.")
    end

    version = wishlist.versions.last
    assert_equal caregiver, version.actor
    assert_equal "live", version.reify.status
    assert_equal [ "live", "in_review" ], version.changeset["status"]
    assert_equal [ "She loves to draw.", "She started cooking dinner on Sundays." ],
                 version.changeset["caregiver_note"]
  end

  test "approving a list records who approved it" do
    wishlist = build_wishlist(status: "in_review")
    staff = users(:staff)

    PaperTrail.request(whodunnit: staff.id) { wishlist.approve! }

    assert_equal staff, wishlist.versions.last.actor
    assert_equal [ "in_review", "live" ], wishlist.versions.last.changeset["status"]
  end
end
