# frozen_string_literal: true

require "test_helper"

class WishlistTest < ActiveSupport::TestCase
  test "asked, chosen, and remaining are sums over the lines" do
    wishlist = build_wishlist
    build_line_item(wishlist: wishlist, price_in_cents: 4_800)
    funded = build_line_item(wishlist: wishlist, price_in_cents: 6_000)
    funded.fund!(build_donation(event: wishlist.event, gift_in_cents: 6_000))

    assert_equal 10_800, wishlist.asked_in_cents
    assert_equal 6_000, wishlist.chosen_in_cents
    assert_equal 4_800, wishlist.remaining_in_cents
    assert_equal 56, wishlist.percent_chosen
  end

  test "an empty list is zero percent chosen rather than a division error" do
    assert_equal 0, build_wishlist.percent_chosen
  end

  test "a gift that would put the list over the cap is refused" do
    wishlist = build_wishlist(event: build_event(per_child_cap_in_cents: 20_000))
    build_line_item(wishlist: wishlist, price_in_cents: 15_000)
    over = wishlist.line_items.build(name: "Bicycle", price_in_cents: 6_000)

    assert_not over.valid?
    assert_includes over.errors[:price_in_cents].first, "$50 left"
    assert_equal 5_000, wishlist.room_in_cents
  end

  test "a list may be filled exactly to the cap" do
    wishlist = build_wishlist(event: build_event(per_child_cap_in_cents: 20_000))
    build_line_item(wishlist: wishlist, price_in_cents: 15_000)
    build_line_item(wishlist: wishlist, price_in_cents: 5_000)

    assert wishlist.at_cap?
  end

  test "a withdrawn gift frees its room under the cap" do
    wishlist = build_wishlist(event: build_event(per_child_cap_in_cents: 20_000))
    line = build_line_item(wishlist: wishlist, price_in_cents: 20_000)
    line.withdraw!

    assert_equal 0, wishlist.asked_in_cents
    assert build_line_item(wishlist: wishlist, price_in_cents: 20_000).persisted?
  end

  test "a typed gift joins the catalog only when one name fits" do
    wishlist = build_wishlist
    hoodie = build_catalog_item(name: "Hoodie", price_in_cents: 4_000)

    assert_equal hoodie, wishlist.add_gift(name: "hoodie", price_in_cents: 4_000).catalog_item
    assert_nil wishlist.add_gift(name: "Telescope", price_in_cents: 4_000).catalog_item
  end

  test "a typed gift above the catalog price waits for staff" do
    wishlist = build_wishlist
    build_catalog_item(name: "Hoodie", price_in_cents: 4_000)

    assert wishlist.add_gift(name: "Hoodie", price_in_cents: 6_000).needs_review_status?
  end

  test "a caregiver changing a gift on a live list sends it back for review" do
    wishlist = build_wishlist(status: "live", approved_at: Time.current)
    line = build_line_item(wishlist: wishlist)

    Current.set(user: wishlist.household.caregiver) { line.update!(price_in_cents: 5_500) }

    assert_equal "in_review", wishlist.reload.status
  end

  test "staff changing a gift leaves a live list live" do
    wishlist = build_wishlist(status: "live", approved_at: Time.current)
    line = build_line_item(wishlist: wishlist)

    Current.set(user: users(:admin)) { line.update!(spec: "Size 11") }

    assert_equal "live", wishlist.reload.status
  end

  test "a list returned to the caregiver carries the reason" do
    wishlist = build_wishlist(status: "in_review")
    wishlist.return_to_caregiver!("Please keep the note about who she is, not her case.")

    assert_equal "draft", wishlist.reload.status
    assert_includes wishlist.review_note, "not her case"
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

  test "a list is fully chosen only once every line is covered" do
    wishlist = build_wishlist
    line = build_line_item(wishlist: wishlist)
    assert_not wishlist.fully_chosen?

    line.fund!(build_donation(event: wishlist.event))
    assert wishlist.reload.fully_chosen?
  end

  test "a list is not shoppable once its event closes" do
    event = build_event(opened_at: 8.weeks.ago, closes_at: 1.week.ago, payout_at: 1.day.from_now)
    assert_not build_wishlist(event: event, status: "live").shoppable?
  end

  test "a list from an unverified household stays private" do
    household = build_household(verification_status: "pending")
    wishlist = build_wishlist(child: build_child(household: household), status: "live")

    assert_not wishlist.shoppable?
    assert_not_includes Wishlist.visible_to_donors, wishlist
  end

  test "a live list from a verified household in an open event is public" do
    wishlist = build_wishlist(status: "live")

    assert wishlist.shoppable?
    assert_includes Wishlist.visible_to_donors, wishlist
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
    staff = users(:admin)

    PaperTrail.request(whodunnit: staff.id) { wishlist.approve! }

    assert_equal staff, wishlist.versions.last.actor
    assert_equal [ "in_review", "live" ], wishlist.versions.last.changeset["status"]
  end
end
