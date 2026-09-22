# frozen_string_literal: true

require "test_helper"

class LineItemTest < ActiveSupport::TestCase
  test "funded is the presence of a donation" do
    line = build_line_item
    assert_not line.funded?

    line.fund!(build_donation(event: line.wishlist.event))
    assert line.funded?
  end

  test "funded_at comes from the donation rather than a column" do
    line = build_line_item
    donation = build_donation(event: line.wishlist.event)
    line.fund!(donation)

    assert_equal donation.created_at, line.funded_at
  end

  test "a blank spec leaves the line in the pool" do
    assert build_line_item(spec: nil).pooled?
    assert build_line_item(spec: "").pooled?
    assert_not build_line_item(spec: "Nike, size L").pooled?
  end

  test "a line above its catalog price is flagged for staff" do
    item = build_catalog_item(price_in_cents: 7_000)
    assert build_line_item(catalog_item: item, price_in_cents: 9_500).above_catalog_price?
    assert_not build_line_item(catalog_item: item, price_in_cents: 7_000).above_catalog_price?
  end

  test "a typed gift with no catalog match is custom" do
    assert build_line_item(catalog_item: nil).custom?
  end

  test "an anonymous donation does not name the funder" do
    line = build_line_item
    line.fund!(build_donation(event: line.wishlist.event, anonymous: true, display_name: "Priya S."))

    assert_equal "Anonymous", line.funder_display_name
  end

  test "shoppable excludes funded and withdrawn lines" do
    wishlist = build_wishlist
    open_line = build_line_item(wishlist: wishlist)
    build_line_item(wishlist: wishlist, status: "withdrawn")
    funded = build_line_item(wishlist: wishlist)
    funded.fund!(build_donation(event: wishlist.event))

    assert_equal [ open_line.id ], wishlist.line_items.shoppable.pluck(:id)
  end
end
