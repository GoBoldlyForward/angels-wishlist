# frozen_string_literal: true

require_relative "families_test_case"

module Admin
  class LineItemsTest < FamiliesTestCase
    setup do
      @household, @wishlist = build_family
      @catalog_item = build_catalog_item(name: "Art supply set", price_in_cents: 4_800)
      @art = build_line_item(wishlist: @wishlist, name: "Art supply set", catalog_item: @catalog_item)
      @cleats = build_line_item(wishlist: @wishlist, name: "Soccer cleats", spec: "Youth size 4", price_in_cents: 5_500)
      @pricey = build_line_item(wishlist: @wishlist, name: "Art supply set, deluxe", catalog_item: @catalog_item,
                                price_in_cents: 6_000, status: "needs_review")
      donor = build_donor(first_name: "Dana", last_name: "Whitlock")
      @donation = build_donation(event: @event, donor: donor, anonymous: true, display_name: nil)
      @art.fund!(@donation)
    end

    test "the index lists every gift and names the donor behind an anonymous one" do
      get admin_line_items_path

      assert_response :success
      assert_select "td .item-name", text: "Art supply set"
      assert_select "td .item-name", text: "Soccer cleats"
      funded = css_select("tbody tr").find { |tr| tr.css(".item-name").first.text.strip == "Art supply set" }
      assert_includes funded.text, "Anonymous"
      assert_includes funded.css(".cell-sub").map(&:text), "Dana Whitlock"
      assert_includes funded.css(".status-badge").text, "Funded"
      assert_select "td .cell-sub", text: "catalog price is $48"
    end

    test "tabs narrow the index" do
      expected = { "open" => [ "Soccer cleats" ], "funded" => [ "Art supply set" ], "specific" => [ "Soccer cleats" ],
                   "pooled" => [], "review" => [ "Art supply set, deluxe" ], "withdrawn" => [] }

      expected.each do |tab, names|
        get admin_line_items_path(tab: tab)
        assert_equal names, css_select("td:first-child .item-name").map { |cell| cell.text.strip }, "on the #{tab} tab"
      end
    end

    test "search, filters, and sort work on the index" do
      get admin_line_items_path(q: "whitlock")
      assert_equal [ "Art supply set" ], css_select("td:first-child .item-name").map { |cell| cell.text.strip }

      get admin_line_items_path(f: { price: "40-80", category: @catalog_item.category_id })
      assert_equal 2, css_select("td:first-child .item-name").size

      get admin_line_items_path(f: { household: @household.id, age: "6-11" }, sort: "price", dir: "desc")
      assert_equal [ "Art supply set, deluxe", "Soccer cleats", "Art supply set" ],
                   css_select("td:first-child .item-name").map { |cell| cell.text.strip }

      %w[status funder category child].each do |key|
        get admin_line_items_path(sort: key)
        assert_response :success
      end
    end

    test "the index exports to CSV" do
      get admin_line_items_path(format: :csv)

      rows = csv_rows
      funded = rows.find { |row| row["Gift"] == "Art supply set" }
      assert_equal 3, rows.size
      assert_equal "funded", funded["Status"]
      assert_equal "Anonymous", funded["Funded by"]
      assert_equal "Dana Whitlock", funded["Donor"]
      assert_equal "Youth size 4", rows.find { |row| row["Gift"] == "Soccer cleats" }["Brand or size"]
    end

    test "the page for a gift shows who it is for and who funded it" do
      get admin_line_item_path(@art)

      assert_response :success
      [ "The gift", "Who it is for", "Funding" ].each { |title| assert_select ".drawer-section h4", text: title }
      assert_select "dd", text: "Dana Whitlock"
      assert_select "dd", text: "Anonymous"
      assert_select "a[href=?]", edit_admin_line_item_path(@art), count: 0
      assert_select "body", text: /Move to another child/, count: 0
    end

    test "editing a gift changes it and records who did it" do
      get edit_admin_line_item_path(@cleats)
      assert_response :success

      patch admin_line_item_path(@cleats), params: { line_item: {
        name: "Soccer cleats", price: "49.50", spec: "Youth size 5", link_url: "https://example.com/cleats",
        catalog_item_id: ""
      } }

      assert_redirected_to admin_line_item_path(@cleats)
      @cleats.reload
      assert_equal 4_950, @cleats.price_in_cents
      assert_equal "Youth size 5", @cleats.spec
      assert_equal "https://example.com/cleats", @cleats.link_url
      assert_recorded_by_staff @cleats, "price_in_cents", [ 5_500, 4_950 ]
      assert @wishlist.reload.live?
    end

    test "a price that would put the list over the cap is refused" do
      patch admin_line_item_path(@cleats), params: { line_item: { name: "Soccer cleats", price: "150" } }

      assert_response :unprocessable_entity
      assert_select ".alert li", text: /over the \$200 cap/
      assert_equal 5_500, @cleats.reload.price_in_cents
    end

    test "a funded gift cannot be edited or withdrawn" do
      get edit_admin_line_item_path(@art)
      assert_redirected_to admin_line_item_path(@art)
      assert_equal "A donor has chosen this gift, so it cannot be changed or withdrawn.", flash[:alert]

      patch admin_line_item_path(@art), params: { line_item: { name: "Something else", price: "10" } }
      assert_redirected_to admin_line_item_path(@art)

      patch withdraw_admin_line_item_path(@art)
      assert_redirected_to admin_line_item_path(@art)

      @art.reload
      assert_equal "Art supply set", @art.name
      assert @art.open_status?
    end

    test "approving a price opens the line and records who did it" do
      patch approve_admin_line_item_path(@pricey)

      assert_redirected_to admin_line_item_path(@pricey)
      assert @pricey.reload.open_status?
      assert_recorded_by_staff @pricey, "status", %w[needs_review open]
    end

    test "withdrawing a gift records who did it" do
      patch withdraw_admin_line_item_path(@cleats)

      assert_redirected_to admin_line_item_path(@cleats)
      assert @cleats.reload.withdrawn_status?
      assert_recorded_by_staff @cleats, "status", %w[open withdrawn]
    end
  end
end
