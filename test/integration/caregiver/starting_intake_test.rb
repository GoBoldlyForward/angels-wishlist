# frozen_string_literal: true

require_relative "intake_test_case"

module Caregiver
  class StartingIntakeTest < IntakeTestCase
    test "a visitor sees the landing page" do
      get caregiver_root_path

      assert_response :success
      assert_select "h1", "Tell us what they want. You do the shopping."
      assert_select "a[href=?]", caregiver_intake_home_path, text: /Start my lists/
      assert_select "#help", text: /We can do this with you/
    end

    test "the landing page says so when lists are closed" do
      @event.update!(opened_at: 2.months.ago, closes_at: 1.day.ago)

      get caregiver_root_path

      assert_select "a[href=?]", caregiver_intake_home_path, count: 0
      assert_select "p", /Lists are not open right now/
    end

    test "step one is open to a visitor" do
      get caregiver_intake_home_path

      assert_response :success
      assert_select "input[name=?]", "home[password]"
      assert_select "select[name=?] option", "home[county]", count: Household::COUNTIES.size + 1
    end

    test "starting intake creates the caregiver, the household, its address, and the enrollment" do
      assert_difference -> { User.caregiver.count } => 1, -> { Household.count } => 1, -> { Address.count } => 1,
                        -> { Enrollment.count } => 1 do
        submit_home(home_fields)
      end

      assert_redirected_to caregiver_intake_children_path
      user = User.find_by!(email: "tanya.okafor@example.com")
      household = user.households.sole
      assert_equal "+14048675309", user.phone
      assert_equal @chapter, household.organization
      assert_equal "The Okafor home", household.display_name
      assert_equal "DeKalb", household.county
      assert_equal "pending", household.verification_status
      assert_equal "1420 Peachtree Way, Decatur, GA 30030", household.mailing_address.to_s
      assert_equal "children", household.enrollment_for(@event).intake_step

      follow_redirect!
      assert_response :success, "the new caregiver is signed in"
    end

    test "the address is optional" do
      assert_no_difference -> { Address.count } do
        submit_home(home_fields(street_line_1: "", city: "", zipcode: ""))
      end

      assert_redirected_to caregiver_intake_children_path
      assert_nil User.find_by!(email: "tanya.okafor@example.com").households.sole.mailing_address
    end

    test "half an address is refused" do
      assert_no_difference -> { User.count } do
        submit_home(home_fields(city: "", zipcode: "3003"))
      end

      assert_response :unprocessable_entity
      assert_select ".field-error", "City can't be blank."
      assert_select ".field-error", "ZIP must be 5 or 9 digits."
    end

    test "missing answers are named" do
      assert_no_difference -> { User.count } do
        submit_home(home_fields(first_name: "", county: "", password: "123"))
      end

      assert_response :unprocessable_entity
      assert_select ".field-error", "First name can't be blank."
      assert_select ".field-error", "County must be chosen from the list."
      assert_select ".field-error", /Password is too short/
    end

    test "an email that already has an account is pointed to sign in" do
      assert_no_difference [ "User.count", "Household.count" ] do
        submit_home(home_fields(email: users(:caregiver).email.upcase))
      end

      assert_response :unprocessable_entity
      assert_select ".flash-alert", /That email already has an account/
      assert_select ".flash-alert a[href=?]", new_user_session_path, text: "Sign in"
    end

    test "a filled honeypot creates nothing" do
      assert_no_difference [ "User.count", "Household.count" ] do
        submit_home(home_fields, nickname: "bot")
      end
    end

    test "a signed-in caregiver editing step one updates the same records" do
      household, enrollment = start_household(step: "lists")
      sign_in users(:caregiver)

      get caregiver_intake_home_path
      assert_select "input[name=?][value=?]", "home[first_name]", "Denise"
      assert_select "input[name=?]", "home[password]", count: 0

      assert_no_difference [ "User.count", "Household.count", "Enrollment.count" ] do
        patch caregiver_intake_home_path,
              params: { home: home_fields(first_name: "Denise", last_name: "Brooks", email: users(:caregiver).email,
                                          county: "Henry", password: "changed-by-form") }
      end

      assert_redirected_to caregiver_intake_children_path
      assert_equal "Henry", household.reload.county
      assert_equal "Decatur", household.mailing_address.city
      assert_equal "lists", enrollment.reload.intake_step
      assert users(:caregiver).reload.valid_password?("password123")
    end

    test "a caregiver with no household yet is sent to step one" do
      sign_in users(:caregiver)

      get caregiver_root_path

      assert_redirected_to caregiver_intake_home_path
    end

    test "a caregiver part way through is sent to the step they left off at" do
      start_household(step: "love_box")
      sign_in users(:caregiver)

      get caregiver_root_path

      assert_redirected_to caregiver_intake_love_box_path
    end

    test "a step not reached yet sends the caregiver back" do
      start_household(step: "children")
      sign_in users(:caregiver)

      get caregiver_intake_payout_path

      assert_redirected_to caregiver_intake_children_path
    end

    test "the steps behind the caregiver are links" do
      start_household(step: "lists")
      sign_in users(:caregiver)

      get caregiver_intake_love_box_path

      assert_select "a.step.done[href=?]", caregiver_intake_home_path
      assert_select "a.step.on[href=?]", caregiver_intake_love_box_path
      assert_select "a.step[href=?]", caregiver_intake_lists_path
      assert_select "a.step[href=?]", caregiver_intake_payout_path, count: 0
    end

    test "intake is closed once the event closes" do
      start_household(step: "lists")
      @event.update!(opened_at: 2.months.ago, closes_at: 1.day.ago)
      sign_in users(:caregiver)

      get caregiver_intake_children_path

      assert_redirected_to caregiver_root_path
      follow_redirect!
      assert_select "p", /Lists are not open right now/
    end
  end
end
