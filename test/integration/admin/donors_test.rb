# frozen_string_literal: true

require_relative "funding_case"

module Admin
  class DonorsTest < FundingCase
    setup do
      @priya = build_donor(first_name: "Priya", last_name: "Sundaram")
      @rotary = build_donor(first_name: "Buckhead", last_name: "Rotary")
      @family = build_donor(first_name: "The Hollis", last_name: "family")
      build_donation(event: @event, donor: @priya, gift_in_cents: 0, general_gift_in_cents: 5_000, fee_in_cents: 150)
      build_donation(event: @event, donor: @priya, gift_in_cents: 0, general_gift_in_cents: 2_500, anonymous: true)
      build_donation(event: @event, donor: @rotary, gift_in_cents: 0, general_gift_in_cents: 50_000)
      build_donation(event: @event, donor: @family, gift_in_cents: 0, general_gift_in_cents: 1_000)
    end

    test "the index lists each donor once with their season added up" do
      get admin_donors_path

      assert_response :success
      assert_select "tbody tr", 3
      assert_select "td", text: /Priya Sundaram/
      assert_select "td", text: /shown as Anonymous/
      assert_select "td", text: "$75.00"
    end

    test "tabs sort donors by the kind of giver their name says they are" do
      get admin_donors_path(tab: "groups")
      assert_select "tbody tr", 1
      assert_select "td", text: /Buckhead Rotary/

      get admin_donors_path(tab: "families")
      assert_select "tbody tr", 1
      assert_select "td", text: /The Hollis family/

      get admin_donors_path(tab: "repeat")
      assert_select "tbody tr", 1
      assert_select "td", text: /Priya Sundaram/
    end

    test "search, filters, and sorting narrow and order the list" do
      get admin_donors_path(q: "rotary")
      assert_select "tbody tr", 1

      get admin_donors_path(f: { fee: "covered" })
      assert_select "tbody tr", 1
      assert_select "td", text: /Priya Sundaram/

      get admin_donors_path(sort: "given", dir: "asc")
      assert_select "tbody tr:first-child td", text: /The Hollis family/
    end

    test "a donor from another event is left out" do
      other = build_event(organization: @chapter, opened_at: 2.years.ago, closes_at: 1.year.ago, payout_at: 1.year.ago)
      build_donation(event: other, donor: build_donor(first_name: "Last", last_name: "Season"))

      get admin_donors_path
      assert_select "td", text: /Last Season/, count: 0
    end

    test "the index exports to CSV" do
      get admin_donors_path(format: :csv)

      assert_response :success
      assert_equal "text/csv", response.media_type
      priya = csv_rows.find { |row| row["Donor"] == "Priya Sundaram" }
      assert_equal "75", priya["Given"]
      assert_equal "2", priya["Donations"]
      assert_equal "0", priya["Gifts chosen"]
      assert_equal "Anonymous", priya["Shown as"]
      assert_equal "Group or team", csv_rows.find { |row| row["Donor"] == "Buckhead Rotary" }["Type"]
    end

    test "the donor page shows the real name behind an anonymous gift" do
      get admin_donor_path(@priya)

      assert_response :success
      assert_select "h1", text: "Priya Sundaram"
      assert_select ".privacy-note", text: /Shown as Anonymous/
      assert_select "tbody tr", 2
    end

    test "resending the receipt from the donor page sends the latest succeeded donation's" do
      get admin_donor_path(@priya)
      latest = @event.donations.where(donor: @priya).recent.first

      assert_select "form[action=?]", resend_receipt_admin_donation_path(latest)
      assert_enqueued_emails 1 do
        post resend_receipt_admin_donation_path(latest)
      end
    end
  end
end
