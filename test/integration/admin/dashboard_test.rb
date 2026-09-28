# frozen_string_literal: true

require_relative "families_test_case"

module Admin
  class DashboardTest < FamiliesTestCase
    setup do
      @household, @wishlist = build_family
      @catalog_item = build_catalog_item(name: "Art supply set")
      @art = build_line_item(wishlist: @wishlist, name: "Art supply set", catalog_item: @catalog_item)
      @ball = build_line_item(wishlist: @wishlist, name: "Soccer ball", price_in_cents: 5_200)
      @art.fund!(build_donation(event: @event, gift_in_cents: 4_800))
      @pending, @waiting = build_family(name: "The Sinclair home", alias_name: "Ruby", list_status: "in_review",
                                        verification_status: "pending")
      enroll(@pending)
      @untouched_household, @untouched = build_family(name: "The Vance home", alias_name: "Theo")
      build_line_item(wishlist: @untouched, name: "Winter coat", price_in_cents: 6_500)
      build_donation(event: @event, status: "disputed")
    end

    test "the overview shows the five figures" do
      get admin_root_path

      assert_response :success
      figures = css_select(".stat-card").to_h { |card| [ card.css(".stat-label").text, card.css(".stat-value").text ] }
      assert_equal "$48", figures["Raised"]
      assert_equal "1 / 3", figures["Gifts chosen"]
      assert_equal "2 / 3", figures["Lists live"]
      assert_equal "3", figures["Households"]
      assert_equal "14", figures["Days left"]
      assert_select ".stat-card", text: /1 not verified/
      assert_select ".stat-card", text: /29% of the \$165 goal/
    end

    test "the overview says what needs attention and why" do
      get admin_root_path

      assert_select ".attention-list a[href=?]", admin_household_path(@pending), text: "The Sinclair home cannot be paid"
      assert_select ".attention-list .att-body", text: /Verification has not cleared/
      assert_select ".attention-list .att-body b", text: "1 household to verify"
      assert_select ".attention-list .att-body b", text: "1 list to review"
      assert_select ".attention-list .att-body b", text: "1 live list with nothing chosen"
      assert_select ".attention-list .att-body b", text: "1 disputed and 0 pending donations"
    end

    test "the overview counts open lines by category and lists what nobody has chosen from" do
      get admin_root_path

      mix = css_select(".mix-row").to_h { |row| [ row.css(".mix-label").text, row.css(".mix-val").text.to_i ] }
      assert_equal({ "Not in the catalog" => 2 }, mix)
      assert_select ".panel-card-head h2", text: "Nothing chosen yet"
      assert_select ".panel-card-head h2", text: "Furthest behind", count: 0
      assert_select ".attention-list a[href=?]", admin_wishlist_path(@untouched), text: "Theo, 9"
    end

    test "the overview renders before any event exists" do
      Event.update_all(deleted_at: Time.current)

      get admin_root_path

      assert_response :success
      assert_select "a[href=?]", admin_events_path, text: /Set up an event/
    end
  end
end
