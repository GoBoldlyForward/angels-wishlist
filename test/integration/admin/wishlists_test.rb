# frozen_string_literal: true

require_relative "families_test_case"

module Admin
  class WishlistsTest < FamiliesTestCase
    setup do
      @household, @wishlist = build_family
      @art = build_line_item(wishlist: @wishlist, name: "Art supply set", price_in_cents: 4_800)
      @ball = build_line_item(wishlist: @wishlist, name: "Soccer ball", price_in_cents: 2_200)
      @pending, @waiting = build_family(name: "The Sinclair home", alias_name: "Ruby", list_status: "in_review",
                                        verification_status: "pending")
    end

    test "the index lists one row per child with what was asked, chosen, and shared" do
      donation = build_donation(event: @event, gift_in_cents: 4_800)
      @art.fund!(donation)

      get admin_wishlists_path

      assert_response :success
      assert_select "td .item-name", text: "Maya, 9"
      assert_select "td .item-name", text: "Ruby, 9"
      row = css_select("tbody tr").find { |tr| tr.text.include?("Maya, 9") }
      assert_equal [ "1 / 2", "$70", "$48", "$48" ], row.css("td .num").first(4).map { |cell| cell.text.strip }
      assert_select ".page-tabs .nav-link", text: /In review\s+1/
      assert_select "body", text: /over cap/i, count: 0
    end

    test "tabs narrow the index to returned, fully chosen, and withdrawn lists" do
      @waiting.return_to_caregiver!("The note names a school.")
      [ @art, @ball ].each { |line| line.fund!(build_donation(event: @event, gift_in_cents: line.price_in_cents)) }
      _household, gone = build_family(name: "The Vance home", alias_name: "Theo", list_status: "withdrawn")

      get admin_wishlists_path(tab: "returned")
      assert_equal [ "Ruby, 9" ], css_select("td .item-name").map { |cell| cell.text.strip }

      get admin_wishlists_path(tab: "chosen")
      assert_equal [ "Maya, 9" ], css_select("td .item-name").map { |cell| cell.text.strip }

      get admin_wishlists_path(tab: "withdrawn")
      assert_equal [ "Theo, 9" ], css_select("td .item-name").map { |cell| cell.text.strip }
      assert gone.withdrawn?
    end

    test "search, filters, and sort work on the index" do
      get admin_wishlists_path(q: "sketchbook", f: { household: @household.id })
      assert_equal [ "Maya, 9" ], css_select("td .item-name").map { |cell| cell.text.strip }

      get admin_wishlists_path(q: "jordan", f: { age: "12-18" })
      assert_select "td .item-name", count: 0

      get admin_wishlists_path(sort: "asked", dir: "asc")
      assert_equal [ "Ruby, 9", "Maya, 9" ], css_select("td .item-name").map { |cell| cell.text.strip }

      %w[share last_gift gifts chosen].each do |key|
        get admin_wishlists_path(sort: key, dir: "desc")
        assert_response :success
      end
    end

    test "the index exports to CSV" do
      get admin_wishlists_path(format: :csv)

      rows = csv_rows
      maya = rows.find { |row| row["Child"] == "Maya" }
      assert_equal 2, rows.size
      assert_equal "Jordan", maya["Legal first name"]
      assert_equal "70.0", maya["Asked"]
      assert_equal "live", maya["Status"]
    end

    test "the page for a list shows what a donor sees and what only staff know" do
      get admin_wishlist_path(@wishlist)

      assert_response :success
      [ "The wishlist", "What a donor sees", "Staff only", "Privacy", "Every line" ].each do |title|
        assert_select ".drawer-section h4", text: title
      end
      assert_select ".drawer-quote", text: "She fills a sketchbook a month."
      assert_select "dd", text: "Jordan"
      assert_select "td .item-name", text: "Art supply set"
      assert_select ".privacy-note", text: /never see a legal name/
    end

    test "approving a list makes it live, records who did it, and tells the caregiver" do
      @pending.verify!

      assert_enqueued_emails 1 do
        patch approve_admin_wishlist_path(@waiting)
      end

      assert_redirected_to admin_wishlist_path(@waiting)
      assert @waiting.reload.live?
      assert_not_nil @waiting.approved_at
      assert_recorded_by_staff @waiting, "status", %w[in_review live]
    end

    test "the caregiver is not told their lists are live while one is still in review" do
      @pending.verify!
      sibling = build_wishlist(child: build_child(household: @pending), event: @event, status: "in_review")

      assert_no_enqueued_emails do
        patch approve_admin_wishlist_path(@waiting)
      end

      assert @waiting.reload.live?
      assert sibling.reload.in_review?
    end

    test "a list cannot be approved while its household is unverified" do
      assert_no_enqueued_emails do
        patch approve_admin_wishlist_path(@waiting)
      end

      assert_redirected_to admin_wishlist_path(@waiting)
      assert_equal "The Sinclair home has to be verified before its lists can go live.", flash[:alert]
      assert @waiting.reload.in_review?

      follow_redirect!
      assert_select ".privacy-note a[href=?]", admin_household_path(@pending), text: "Open the household"
      assert_select "form[action=?]", approve_admin_wishlist_path(@waiting), count: 0
    end

    test "returning a list needs a reason" do
      assert_no_enqueued_emails do
        patch return_to_caregiver_admin_wishlist_path(@waiting), params: { reason: "" }
      end

      assert_equal "Say what the caregiver needs to change.", flash[:alert]
      assert @waiting.reload.in_review?
    end

    test "returning a list sends it back with the reason and records who did it" do
      assert_enqueued_emails 1 do
        patch return_to_caregiver_admin_wishlist_path(@waiting), params: { reason: "The note names a school." }
      end

      assert_redirected_to admin_wishlist_path(@waiting)
      assert @waiting.reload.draft?
      assert_equal "The note names a school.", @waiting.review_note
      assert_recorded_by_staff @waiting, "status", %w[in_review draft]

      follow_redirect!
      assert_select ".privacy-note", text: /The note names a school/
    end

    test "withdrawing a list records who did it" do
      patch withdraw_admin_wishlist_path(@wishlist)

      assert_redirected_to admin_wishlist_path(@wishlist)
      assert @wishlist.reload.withdrawn?
      assert_recorded_by_staff @wishlist, "status", %w[live withdrawn]
    end

    test "a list on another event is not found" do
      elsewhere = build_wishlist(child: build_child(household: @household), event: build_event(organization: @chapter, opened_at: 1.year.ago, closes_at: 11.months.ago))

      get admin_wishlist_path(elsewhere)

      assert_response :not_found
    end
  end
end
