# frozen_string_literal: true

require_relative "intake_test_case"

module Caregiver
  class AccessTest < IntakeTestCase
    setup do
      @household, @enrollment = start_household(step: "review")
      @list = add_child_with_list(@household, first_name: "Amelia")

      @other_household, = start_household(caregiver: build_caregiver(first_name: "Tanya", last_name: "Okafor"))
      @other_list = add_child_with_list(@other_household, first_name: "Jordan", gifts: [ [ "Telescope", 9_000 ] ])
    end

    test "every step asks a visitor to sign in" do
      %i[children love_box lists payout review submission].each do |step|
        get public_send("caregiver_intake_#{step}_path")
        assert_redirected_to new_user_session_path, "#{step} was open to a visitor"
      end
    end

    test "staff and donors are turned away" do
      %i[staff donor].each do |role|
        sign_in users(role)

        get caregiver_root_path
        assert_redirected_to root_path

        get caregiver_intake_home_path
        assert_redirected_to root_path
      end
    end

    test "a caregiver sees only their own household" do
      sign_in users(:caregiver)

      get caregiver_intake_review_path

      assert_select ".disclosure", /Amelia/
      assert_no_match(/Jordan|Telescope|Okafor/, response.body)
    end

    test "a caregiver cannot open another household's list" do
      sign_in users(:caregiver)

      get caregiver_intake_list_path(@other_list)

      assert_response :not_found
    end

    test "a caregiver cannot add to another household's list" do
      sign_in users(:caregiver)

      assert_no_difference -> { @other_list.line_items.count } do
        post caregiver_intake_list_gifts_path(@other_list), params: { gift: { name: "Bike", price: "20" } }
      end

      assert_response :not_found
    end

    test "a caregiver cannot remove from another household's list" do
      sign_in users(:caregiver)

      assert_no_difference -> { @other_list.line_items.count } do
        delete caregiver_intake_list_gift_path(@other_list, @other_list.line_items.first)
      end

      assert_response :not_found
    end

    test "a caregiver cannot remove another household's gift through their own list" do
      sign_in users(:caregiver)

      assert_no_difference -> { @other_list.line_items.count } do
        delete caregiver_intake_list_gift_path(@list, @other_list.line_items.first)
      end

      assert_response :not_found
    end

    test "a caregiver cannot send in another household's list" do
      @other_household.enrollment_for(@event).update!(submitted_at: Time.current)
      @enrollment.update!(submitted_at: Time.current)
      sign_in users(:caregiver)

      post caregiver_intake_list_submission_path(@other_list)

      assert_response :not_found
      assert @other_list.reload.draft?
    end

    test "a caregiver cannot change another household's child" do
      sign_in users(:caregiver)

      patch caregiver_intake_children_path, params: { children: {
        "c1" => { id: @other_list.child_id, legal_first_name: "Renamed", birthdate: 9.years.ago.to_date, gender: "girl" }
      } }

      assert_response :not_found
      assert_equal "Jordan", @other_list.child.reload.legal_first_name
    end
  end
end
