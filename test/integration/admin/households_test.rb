# frozen_string_literal: true

require_relative "families_test_case"

module Admin
  class HouseholdsTest < FamiliesTestCase
    setup do
      @agency = build_organization(name: "Bethany Christian Services", kind: "agency", parent: @chapter)
      @household, @wishlist = build_family(county: "Clayton County", placing_organization: @agency)
      build_line_item(wishlist: @wishlist, name: "Art supply set", price_in_cents: 4_800)
      build_line_item(wishlist: @wishlist, name: "Soccer ball", price_in_cents: 2_200)
      @pending, @waiting_list = build_family(name: "The Sinclair home", alias_name: "Ruby", list_status: "in_review",
                                             verification_status: "pending", payout_method: "none",
                                             stripe_account_id: nil, county: "Douglas County")
    end

    test "the index lists the chapter's households with their figures" do
      build_donation(event: @event, gift_in_cents: 0, general_gift_in_cents: 3_500)

      get admin_households_path

      assert_response :success
      assert_select "td .item-name", text: "The Brooks home"
      assert_select "td .item-name", text: "The Sinclair home"
      assert_select "td", text: /\$35\s+of \$70 asked/
      assert_select ".page-tabs .nav-link", text: /Pending\s+1/
      assert_select ".page-tabs .nav-link", text: /No payout method\s+1/
    end

    test "the index leaves out another chapter's households and archived ones" do
      build_household(organization: build_organization, display_name: "The Elsewhere home")
      build_household(organization: @chapter, display_name: "The Archived home", archived_at: 1.day.ago)

      get admin_households_path

      assert_select "td .item-name", text: "The Elsewhere home", count: 0
      assert_select "td .item-name", text: "The Archived home", count: 0
    end

    test "tabs, search, filters, and sort narrow and order the index" do
      get admin_households_path(tab: "pending")
      assert_select "td .item-name", text: "The Sinclair home"
      assert_select "td .item-name", text: "The Brooks home", count: 0

      get admin_households_path(q: "bethany")
      assert_select "td .item-name", text: "The Brooks home"
      assert_select "td .item-name", text: "The Sinclair home", count: 0

      get admin_households_path(f: { county: "Douglas County" })
      assert_select "td .item-name", text: "The Sinclair home"
      assert_select "td .item-name", text: "The Brooks home", count: 0

      get admin_households_path(sort: "asked", dir: "asc")
      assert_equal [ "The Sinclair home", "The Brooks home" ], css_select("td .item-name").map { |cell| cell.text.strip }

      get admin_households_path(sort: "share", dir: "asc")
      assert_response :success
    end

    test "the returning tab holds households with a list on an earlier event" do
      earlier = build_event(organization: @chapter, opened_at: 1.year.ago, closes_at: 11.months.ago, payout_at: 11.months.ago)
      build_wishlist(child: @household.children.first, event: earlier, status: "closed")

      get admin_households_path(tab: "returning")

      assert_select "td .item-name", text: "The Brooks home"
      assert_select "td .item-name", text: "The Sinclair home", count: 0
    end

    test "the index exports to CSV" do
      get admin_households_path(format: :csv)

      rows = csv_rows
      brooks = rows.find { |row| row["Household"] == "The Brooks home" }
      assert_equal 2, rows.size
      assert_equal "70.0", brooks["Asked"]
      assert_equal "Bethany Christian Services", brooks["Agency"]
      assert_equal "Verification has not cleared.", rows.find { |row| row["Household"] == "The Sinclair home" }["Cannot be paid because"]
    end

    test "the page for a household shows every section" do
      enroll(@household, picks: { "drink" => { "picks" => [ "Hot chocolate" ] } })

      get admin_household_path(@household)

      assert_response :success
      %w[Contact Verification Payout Children].each { |title| assert_select ".drawer-section h4", text: title }
      assert_select ".drawer-section h4", text: "Love Box"
      assert_select ".drawer-section h4", text: "Spending agreement"
      assert_select "dd", text: "Hot chocolate"
      assert_select "td", text: "Jordan"
      assert_select "td .item-name a[href=?]", admin_wishlist_path(@wishlist), text: /Maya, 9/
    end

    test "verifying a household records who did it and approves nothing" do
      patch verify_admin_household_path(@pending)

      assert_redirected_to admin_household_path(@pending)
      assert @pending.reload.verification_verified?
      assert_not_nil @pending.verified_at
      assert_recorded_by_staff @pending, "verification_status", %w[pending verified]
      assert @waiting_list.reload.in_review?
    end

    test "a verified household with lists in review prompts staff to review them" do
      @pending.verify!

      get admin_household_path(@pending)

      assert_select ".privacy-note a[href=?]", admin_wishlist_path(@waiting_list), text: "Ruby's list"
    end

    test "placing a household on hold needs a reason" do
      patch hold_admin_household_path(@household), params: { reason: "  " }

      assert_redirected_to admin_household_path(@household)
      assert_equal "Give a reason to place a household on hold.", flash[:alert]
      assert @household.reload.verification_verified?
    end

    test "placing a household on hold records the reason and who did it" do
      patch hold_admin_household_path(@household), params: { reason: "Placement change reported." }

      assert_redirected_to admin_household_path(@household)
      assert @household.reload.verification_hold?
      assert_equal "Placement change reported.", @household.hold_reason
      assert_recorded_by_staff @household, "verification_status", %w[verified hold]

      follow_redirect!
      assert_select ".privacy-note.danger", text: /Placement change reported/
    end

    test "archiving a household takes it off the index" do
      patch archive_admin_household_path(@household)

      assert_redirected_to admin_households_path
      assert @household.reload.archived?
      follow_redirect!
      assert_select "td .item-name", text: "The Brooks home", count: 0
    end

    test "staff add a household whose caregiver is emailed a link to set a password" do
      assert_emails 1 do
        assert_difference [ "Household.count", "User.caregiver.count", "Enrollment.count" ], 1 do
          post admin_households_path, params: { household: {
            first_name: "Rosa", last_name: "Delgado", email: "rosa.delgado@example.com", phone: "",
            county: "Fulton", placing_organization_id: @agency.id, payout_method: "gift_card",
            street_line_1: "12 Peachtree Way", city: "Atlanta", state: "GA", zipcode: "30303"
          } }
        end
      end

      household = Household.find_by!(display_name: "The Delgado home")
      assert_redirected_to admin_household_path(household)
      assert household.verification_pending?
      assert_equal @chapter, household.organization
      assert_equal @agency, household.placing_organization
      assert_equal "12 Peachtree Way, Atlanta, GA 30303", household.mailing_address.to_s
      assert_equal @event, household.enrollments.sole.event
      assert_equal [ "rosa.delgado@example.com" ], ActionMailer::Base.deliveries.last.to
      assert_not household.caregiver.valid_password?("")
      assert_equal @staff, household.versions.last.actor
    end

    test "a household that cannot be saved comes back with what is wrong" do
      assert_no_difference [ "Household.count", "User.count" ] do
        post admin_households_path, params: { household: { first_name: "Rosa", last_name: "", email: "not an email" } }
      end

      assert_response :unprocessable_entity
      assert_select ".alert li", text: "Last name can't be blank"
    end

    test "editing a household changes its contact details, agency, and payout method" do
      patch admin_household_path(@household), params: { household: {
        first_name: "Denise", last_name: "Brooks", email: @household.caregiver.email, phone: "+14045550134",
        display_name: "The Brooks home", county: "Cobb", placing_organization_id: "", payout_method: "gift_card",
        street_line_1: "48 Oak Street", city: "Marietta", state: "GA", zipcode: "30060"
      } }

      assert_redirected_to admin_household_path(@household)
      @household.reload
      assert_equal "Cobb", @household.county
      assert_nil @household.placing_organization
      assert @household.payout_via_gift_card?
      assert_equal "Marietta", @household.mailing_address.city
      assert_equal "+14045550134", @household.caregiver.phone
      assert_recorded_by_staff @household, "payout_method", %w[stripe gift_card]
    end

    test "the forms render" do
      get new_admin_household_path
      assert_response :success
      assert_select "select[name=?] option", "household[placing_organization_id]", text: "Bethany Christian Services"

      get edit_admin_household_path(@household)
      assert_response :success
      assert_select "input[name=?][value=?]", "household[display_name]", "The Brooks home"
    end
  end
end
