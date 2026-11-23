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
  test "a funded gift cannot be changed or removed" do
    line = build_line_item
    line.fund!(build_donation(event: line.wishlist.event))

    assert_not line.update(price_in_cents: 9_000)
    assert_not line.destroy
    assert line.reload.persisted?
  end

  test "a gift under five dollars is refused" do
    line = build_wishlist.line_items.build(name: "Stickers", price_in_cents: 300)

    assert_not line.valid?
  end

  test "changing a line status records who changed it" do
    line = build_line_item(status: "needs_review")
    staff = users(:admin)

    PaperTrail.request(whodunnit: staff.id) { line.update!(status: "open") }

    assert_equal staff, line.versions.last.actor
    assert_equal [ "needs_review", "open" ], line.versions.last.changeset["status"]
  end

  test "funding a line is not an audited change" do
    line = build_line_item

    assert_no_difference -> { line.versions.count } do
      line.fund!(build_donation(event: line.wishlist.event))
    end
  end

  test "split prices are whole dollars that add up to the line, with leftover cents on the first part" do
    assert_equal [ 5_000, 5_000, 5_000, 5_000 ], build_line_item(price_in_cents: 20_000).split_prices(4)
    assert_equal [ 6_700, 6_700, 6_600 ], build_line_item(price_in_cents: 20_000).split_prices(3)
    assert_equal [ 1_699, 1_600, 1_500 ], build_line_item(price_in_cents: 4_799).split_prices(3)
  end

  test "a line splits only into parts of $5 or more, ten at most" do
    assert_empty build_line_item(price_in_cents: 999).split_counts
    assert_equal [ 2 ], build_line_item(price_in_cents: 1_499).split_counts
    assert_equal [ 2, 3 ], build_line_item(price_in_cents: 1_500).split_counts
    assert_equal (2..10).to_a, build_line_item(price_in_cents: 20_000).split_counts
  end

  test "splitting withdraws the line for open parts that keep its details and the list's total" do
    event = build_event
    wishlist = build_wishlist(child: build_child(household: build_household(organization: event.organization)), event: event)
    other = build_wishlist(child: build_child(household: build_household(organization: event.organization)), event: event)
    item = build_catalog_item(organization: event.organization, price_in_cents: 4_000)
    line = build_line_item(wishlist: wishlist, name: "Clothes", price_in_cents: 10_001, spec: "Girls 10",
                           link_url: "https://example.com/clothes", catalog_item: item, status: "needs_review",
                           created_at: 3.days.ago)
    build_line_item(wishlist: other, price_in_cents: 7_000)
    build_donation(event: event, gift_in_cents: 9_000)
    shares = event.shares

    parts = line.split!(3)

    assert line.reload.withdrawn_status?
    assert_equal [ "Clothes (part 1 of 3)", "Clothes (part 2 of 3)", "Clothes (part 3 of 3)" ], parts.map(&:name)
    assert_equal [ 3_401, 3_300, 3_300 ], parts.map(&:price_in_cents)
    parts.each(&:reload).each do |part|
      assert part.open_status?
      assert_equal [ "Girls 10", "https://example.com/clothes", item, line.created_at ],
                   [ part.spec, part.link_url, part.catalog_item, part.created_at ]
    end
    assert_equal 10_001, wishlist.asked_in_cents
    assert_equal shares, event.reload.shares
  end

  test "a funded, withdrawn, or too small line is not split" do
    funded = build_line_item
    funded.fund!(build_donation(event: funded.wishlist.event))
    {
      funded => "A donor has chosen this gift, so it cannot be split.",
      build_line_item(status: "withdrawn") => "This gift is withdrawn, so it cannot be split.",
      build_line_item(price_in_cents: 900) => "A gift under $10 cannot be split into gifts of $5 or more.",
      build_line_item(price_in_cents: 1_400) => "This gift splits into at most 2 gifts of $5 or more."
    }.each do |line, reason|
      error = assert_raises(ActiveRecord::RecordInvalid) { line.split!(3) }

      assert_equal reason, error.record.errors.full_messages.to_sentence
      assert_equal [ line ], line.wishlist.line_items.reload.to_a
    end
  end
end
