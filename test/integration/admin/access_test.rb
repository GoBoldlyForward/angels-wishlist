# frozen_string_literal: true

require_relative "funding_case"

module Admin
  class AccessTest < FundingCase
    PAGES = %i[admin_donors_path admin_donations_path new_admin_donation_path admin_payouts_path
               new_admin_impact_statement_path admin_events_path admin_categories_path admin_catalog_items_path
               admin_organizations_path].freeze

    test "a donor is turned away from every page" do
      sign_out users(:staff)
      sign_in users(:donor)

      PAGES.each do |page|
        get send(page)
        assert_redirected_to root_path, "#{page} let a donor in"
      end
    end

    test "a caregiver cannot build payouts or record a gift" do
      sign_out users(:staff)
      sign_in users(:caregiver)
      build_list
      build_donation(event: @event)

      assert_no_difference -> { Payout.count } do
        post build_admin_payouts_path
      end
      assert_redirected_to root_path

      assert_no_difference -> { Donation.count } do
        post admin_donations_path, params: { offline_gift: { donor_name: "A", email: "a@example.com", amount_in_dollars: "50" } }
      end
      assert_redirected_to root_path
    end

    test "a signed-out visitor is sent to sign in" do
      sign_out users(:staff)

      get admin_donations_path
      assert_redirected_to new_user_session_path
    end

    test "funding pages ask for an event when there is none" do
      Event.find_each(&:destroy!)

      get admin_donations_path
      assert_redirected_to admin_events_path
    end
  end
end
