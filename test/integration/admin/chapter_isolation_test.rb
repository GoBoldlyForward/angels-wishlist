# frozen_string_literal: true

require "test_helper"

module Admin
  # Two chapters each run a season. An organizer of one reaches nothing of the other's.
  class ChapterIsolationTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    setup do
      @atlanta = season("Atlanta Angels", "The Brooks home", "Maya")
      @nashville = season("Nashville Angels", "The Whitlock home", "Juniper")
      @organizer = build_organizer(organization: @atlanta[:chapter])
      sign_in @organizer
    end

    test "every index shows only the chapter's own records" do
      {
        admin_households_path => [ "The Brooks home", "The Whitlock home" ],
        admin_wishlists_path => [ "Maya", "Juniper" ],
        admin_donations_path => [ "Atlanta donor", "Nashville donor" ],
        admin_donors_path => [ "Atlanta donor", "Nashville donor" ],
        admin_categories_path => [ "Atlanta shelf", "Nashville shelf" ],
        admin_catalog_items_path => [ "Atlanta blocks", "Nashville blocks" ],
        admin_events_path => [ "Atlanta Christmas", "Nashville Christmas" ],
        admin_organizations_path => [ "Atlanta Angels", "Nashville Angels" ]
      }.each do |path, (own, other)|
        get path
        assert_response :success
        assert_includes response.body, own, "#{path} is missing the chapter's own record"
        assert_not_includes response.body, other, "#{path} shows the other chapter's record"
      end
    end

    test "the audit trail shows only the chapter's own changes" do
      get admin_versions_path

      assert_includes response.body, "The Brooks home"
      assert_not_includes response.body, "The Whitlock home"
    end

    test "every record of the other chapter is out of reach" do
      other = @nashville
      [
        admin_household_path(other[:household]), edit_admin_household_path(other[:household]),
        admin_wishlist_path(other[:wishlist]), admin_line_item_path(other[:line_item]),
        admin_donation_path(other[:donation]), admin_payout_path(other[:payout]),
        admin_event_path(other[:event]), edit_admin_category_path(other[:category]),
        edit_admin_catalog_item_path(other[:catalog_item]), admin_organization_path(other[:chapter])
      ].each do |path|
        # A request that ends in a 404 drops the test sign-in, so each probe signs in again.
        sign_in @organizer
        get path
        assert_response :not_found, "#{path} reached the other chapter"
      end
    end

    test "the other chapter's records cannot be changed" do
      other = @nashville

      [ verify_admin_household_path(other[:household]), refund_admin_donation_path(other[:donation]),
        send_funds_admin_payout_path(other[:payout]) ].each do |path|
        sign_in @organizer
        patch path
        assert_response :not_found, "#{path} reached the other chapter"
      end

      assert other[:household].reload.verification_pending?
      assert other[:donation].reload.succeeded?
      assert other[:payout].reload.scheduled?
    end

    test "switching to a chapter the organizer does not belong to is refused" do
      patch current_organization_path, params: { organization_id: @nashville[:chapter].id }

      get admin_households_path
      assert_not_includes response.body, "The Whitlock home"
    end

    test "an organizer of both chapters sees each after switching" do
      sign_in build_organizer(organization: @atlanta[:chapter]).tap { |user|
        OrganizationMembership.create!(user: user, organization: @nashville[:chapter])
      }

      patch current_organization_path, params: { organization_id: @nashville[:chapter].id }
      get admin_households_path

      assert_includes response.body, "The Whitlock home"
      assert_not_includes response.body, "The Brooks home"
    end

    private

    def season(name, household_name, alias_name)
      city = name.split.first
      chapter = build_organization(name: name)
      event = build_event(organization: chapter, name: "#{city} Christmas")
      category = build_category(organization: chapter, name: "#{city} shelf")
      catalog_item = build_catalog_item(category: category, name: "#{city} blocks")
      household = build_household(organization: chapter, display_name: household_name, verification_status: "pending")
      PaperTrail.request(whodunnit: household.caregiver_id) { household.update!(county: "#{city} County") }
      wishlist = build_wishlist(child: build_child(household: household, display_name: alias_name), event: event)
      line_item = build_line_item(wishlist: wishlist)
      donation = build_donation(event: event, display_name: "#{city} donor",
                                donor: build_donor(first_name: city, last_name: "donor"))
      payout = Payout.create!(household: household, event: event, amount_in_cents: 1_000, status: "scheduled",
                              method: "stripe")
      { chapter:, event:, category:, catalog_item:, household:, wishlist:, line_item:, donation:, payout: }
    end
  end
end
