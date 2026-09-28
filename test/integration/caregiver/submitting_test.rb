# frozen_string_literal: true

require_relative "intake_test_case"

module Caregiver
  class SubmittingTest < IntakeTestCase
    include ActionMailer::TestHelper

    setup do
      @household, @enrollment = start_household(step: "review")
      sign_in users(:caregiver)
    end

    test "review shows each child as donors will see them" do
      list = add_child_with_list(@household, first_name: "Amelia", interests: %w[drawing soccer],
                                             caregiver_note: "Draws on every napkin in the house.")
      make_ready(@household, @enrollment)

      get caregiver_intake_review_path

      assert_response :success
      assert_select ".kid-name", "#{list.child.display_name}, 9"
      assert_select ".tag", "drawing"
      assert_select ".gift-row", /Skateboard and helmet/
      assert_select ".disclosure", /Donors see: #{list.child.display_name}, 9, girl, Clayton County, drawing, soccer/
      assert_select ".disclosure", /They do not see Amelia, the birthdate, your name, or your address/
      assert_select "a[href=?]", caregiver_intake_love_box_path, text: "Edit box"
      assert_select ".fund-line", /Holiday celebrated\s*Christmas/
      assert_select "form[action=?] button", caregiver_intake_submission_path, text: "Submit my lists"
    end

    test "submitting is blocked until every blocker clears" do
      get caregiver_intake_review_path
      assert_select ".blockers li", 5
      assert_select "button[disabled]", "Submit my lists"
      assert_submission_refused

      list = add_child_with_list(@household, gifts: [])
      assert_submission_refused

      build_line_item(wishlist: list)
      assert_submission_refused

      @enrollment.love_box_selection.assign(full_love_box)
      @enrollment.save!
      assert_submission_refused

      @household.update!(payout_method: "gift_card")
      assert_submission_refused

      @enrollment.agree_to_spending!
      get caregiver_intake_review_path
      assert_select ".blockers", 0

      post caregiver_intake_submission_path
      assert_redirected_to caregiver_intake_submission_path
      assert @enrollment.reload.submitted?
    end

    test "submitting moves every list to in review and sends the email" do
      lists = [ add_child_with_list(@household, first_name: "Amelia"), add_child_with_list(@household, first_name: "Marcus") ]
      make_ready(@household, @enrollment)

      assert_enqueued_email_with CaregiverMailer, :lists_received, args: [ @enrollment ] do
        post caregiver_intake_submission_path
      end

      assert_redirected_to caregiver_intake_submission_path
      assert_equal %w[in_review in_review], lists.map { |list| list.reload.status }
      assert lists.all? { |list| list.submitted_at.present? }

      follow_redirect!
      assert_select "h1", "2 lists are in."
      assert_select ".flow-step", 3
      assert_select ".flow-step b", "Now to #{@event.closes_at.strftime("%B %-d")}"
      assert_select ".flow-step b", @event.payout_at.strftime("%B %-d")
      assert_no_match(/text|receipt|January|Prototype/i, css_select("main").text)
    end

    test "submitting twice changes nothing" do
      add_child_with_list(@household)
      make_ready(@household, @enrollment)
      post caregiver_intake_submission_path
      submitted_at = @enrollment.reload.submitted_at

      assert_no_enqueued_emails do
        post caregiver_intake_submission_path
      end

      assert_redirected_to caregiver_root_path
      assert_equal submitted_at, @enrollment.reload.submitted_at
    end

    test "a returned list can be fixed and resubmitted" do
      list = add_child_with_list(@household, first_name: "Amelia")
      make_ready(@household, @enrollment)
      post caregiver_intake_submission_path
      list.reload.return_to_caregiver!("Please leave the school name out of the note.")

      get caregiver_root_path
      assert_select ".status-returned", "Needs a change"
      assert_select "#list-#{list.id}", /Please leave the school name out of the note/
      assert_select "form[action=?]", caregiver_intake_list_submission_path(list)

      post caregiver_intake_list_submission_path(list)

      assert_redirected_to caregiver_root_path
      assert list.reload.in_review?
      assert_nil list.review_note
      follow_redirect!
      assert_select ".flash-notice", "Amelia's list is with staff for review."
    end

    test "a list with no gifts cannot be sent in" do
      list = add_child_with_list(@household)
      make_ready(@household, @enrollment)
      post caregiver_intake_submission_path
      list.reload.return_to_caregiver!("Too many gifts.")
      list.line_items.each(&:destroy!)

      post caregiver_intake_list_submission_path(list)

      assert_redirected_to caregiver_intake_list_path(list)
      assert list.reload.draft?
    end

    private

    def assert_submission_refused
      assert_no_enqueued_emails do
        post caregiver_intake_submission_path
      end

      assert_redirected_to caregiver_intake_review_path
      assert_not @enrollment.reload.submitted?
    end
  end
end
