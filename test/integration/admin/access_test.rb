# frozen_string_literal: true

require_relative "families_test_case"

module Admin
  class AccessTest < FamiliesTestCase
    setup do
      @household, @wishlist = build_family(verification_status: "pending", list_status: "in_review")
      @line_item = build_line_item(wishlist: @wishlist, status: "needs_review")
      @donation = build_donation(event: @event, note_to_family: "Thinking of you.")
      sign_out @staff
    end

    test "a caregiver and a donor are turned away from every staff page" do
      %i[caregiver donor].each do |role|
        sign_in users(role)

        pages.each do |path|
          get path
          assert_redirected_to root_path, "#{role} reached #{path}"
          assert_equal "That area is for staff.", flash[:alert]
        end

        sign_out users(role)
      end
    end

    test "a visitor who is not signed in is sent to sign in" do
      pages.each do |path|
        get path

        if path.include?(".csv")
          assert_response :unauthorized, "a visitor reached #{path}"
        else
          assert_redirected_to new_user_session_path, "a visitor reached #{path}"
        end
      end
    end

    test "someone who is not staff cannot change a record" do
      sign_in users(:caregiver)

      patch verify_admin_household_path(@household)
      patch hold_admin_household_path(@household), params: { reason: "No reason." }
      patch archive_admin_household_path(@household)
      patch approve_admin_wishlist_path(@wishlist)
      patch withdraw_admin_wishlist_path(@wishlist)
      patch withdraw_admin_line_item_path(@line_item)
      patch approve_admin_donor_note_path(@donation)
      post admin_households_path, params: { household: { first_name: "A", last_name: "B", email: "a@example.com" } }

      assert_redirected_to root_path
      assert @household.reload.verification_pending?
      assert_not @household.archived?
      assert @wishlist.reload.in_review?
      assert @line_item.reload.needs_review_status?
      assert_nil @donation.reload.note_approved_at
      assert_not User.exists?(email: "a@example.com")
    end

    private

    def pages
      [ admin_root_path, admin_households_path, admin_households_path(format: :csv), new_admin_household_path,
        admin_household_path(@household), edit_admin_household_path(@household),
        admin_wishlists_path, admin_wishlists_path(format: :csv), admin_wishlist_path(@wishlist),
        admin_line_items_path, admin_line_items_path(format: :csv), admin_line_item_path(@line_item),
        edit_admin_line_item_path(@line_item), admin_inbox_path, admin_love_box_path,
        admin_love_box_path(format: :csv), admin_versions_path, admin_versions_path(format: :csv) ]
    end
  end
end
