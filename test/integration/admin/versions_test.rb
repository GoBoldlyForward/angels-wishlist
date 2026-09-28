# frozen_string_literal: true

require_relative "families_test_case"

module Admin
  class VersionsTest < FamiliesTestCase
    setup do
      @household, @wishlist = build_family(verification_status: "pending")
      @line_item = build_line_item(wishlist: @wishlist, name: "Art supply set")
      PaperTrail.request(whodunnit: @staff.id) { @household.verify! }
      PaperTrail.request(whodunnit: @household.caregiver_id) { @wishlist.update!(caregiver_note: "She draws every day.") }
    end

    test "the audit trail shows who changed what, newest first" do
      get admin_versions_path

      assert_response :success
      first = css_select("tbody tr").first
      assert_includes first.text, "Denise Brooks"
      assert_includes first.text, "Maya's list"
      assert_includes first.css(".audit-changes").text.squish, "Caregiver note: She fills a sketchbook a month. → She draws every day."

      verified = css_select("tbody tr").find { |tr| tr.css(".audit-changes").text.include?("pending → verified") }
      assert_includes verified.text, "Sam Reed"
      assert_select "td .item-name a[href=?]", admin_household_path(@household), text: "The Brooks home"
      assert_select "td .item-name a[href=?]", admin_line_item_path(@line_item), text: "Art supply set"
    end

    test "the audit trail filters by record type and by who" do
      get admin_versions_path(f: { type: "Household", actor: @staff.id })

      rows = css_select("tbody tr")
      assert_equal 1, rows.size
      assert_includes rows.first.css(".audit-changes").text, "pending → verified"

      get admin_versions_path(f: { type: "LineItem" }, tab: "create")
      assert_equal [ "Art supply set" ], css_select("td .item-name").map { |cell| cell.text.strip }
    end

    test "the audit trail is paginated" do
      30.times { |index| @wishlist.update!(caregiver_note: "Note #{index}") }

      get admin_versions_path

      assert_equal 25, css_select("tbody tr").size
      assert_select ".pagination .page-link", text: "2"

      get admin_versions_path(page: 2)
      assert_response :success
      assert_operator css_select("tbody tr").size, :<, 25
    end

    test "a removed record is named without a link" do
      @line_item.destroy!

      get admin_versions_path(f: { type: "LineItem" })

      assert_response :success
      assert_select "td .item-name", text: "Art supply set"
      assert_select "td .item-name a", count: 0
    end

    test "the audit trail exports to CSV" do
      get admin_versions_path(format: :csv, f: { type: "Household" }, tab: "update")

      rows = csv_rows
      assert_equal 1, rows.size
      assert_equal "Sam Reed", rows.first["Who"]
      assert_includes rows.first["What changed"], 'verification_status: "pending" -> "verified"'
    end
  end
end
