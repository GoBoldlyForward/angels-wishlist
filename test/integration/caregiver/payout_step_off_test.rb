# frozen_string_literal: true

require_relative "intake_test_case"

module Caregiver
  class PayoutStepOffTest < IntakeTestCase
    include ActionMailer::TestHelper

    setup do
      @chapter.update!(collects_payout_details: false)
      @household, @enrollment = start_household(step: "lists")
      add_child_with_list(@household)
      @enrollment.love_box_selection.assign(full_love_box)
      @enrollment.save!
      sign_in users(:caregiver)
    end

    test "lists lead straight to review, and the step is not shown" do
      patch finish_caregiver_intake_lists_path

      assert_redirected_to caregiver_intake_review_path
      assert_equal "review", @enrollment.reload.intake_step

      follow_redirect!
      assert_select ".steps .step", 5
      assert_select ".steps .step-name", text: "Getting paid", count: 0
      assert_select ".review-side", text: /Paid by/, count: 0
      assert_select ".blockers", 0
    end

    test "lists are sent in with no way to be paid and no agreement" do
      @enrollment.update!(intake_step: "review")

      assert_enqueued_email_with CaregiverMailer, :lists_received, args: [ @enrollment ] do
        post caregiver_intake_submission_path
      end

      assert @enrollment.reload.submitted?
      assert @household.reload.payout_via_none?
      @household.update!(verification_status: "verified")
      assert_equal "No payout method on file.", @household.payout_blocker

      follow_redirect!
      assert_select ".flow-step", /send your household's\s+share\./

      get caregiver_root_path
      assert_select ".review-side", /We will ask how you would like to be paid before your share is sent/
      assert_select "a[href=?]", caregiver_intake_payout_path, count: 0
    end

    test "the step's own pages pass a caregiver on" do
      @enrollment.update!(intake_step: "payout")

      get caregiver_intake_payout_path
      assert_redirected_to caregiver_intake_review_path
      assert_equal "review", @enrollment.reload.intake_step

      post caregiver_intake_stripe_connection_path
      assert_redirected_to caregiver_intake_review_path
      assert @household.reload.payout_via_none?
    end

    test "the step cannot be used to jump ahead" do
      get caregiver_intake_payout_path

      assert_redirected_to caregiver_intake_lists_path
      assert_equal "lists", @enrollment.reload.intake_step
    end

    test "switching the step back on asks a submitted caregiver for it" do
      @enrollment.update!(intake_step: "review")
      post caregiver_intake_submission_path
      @chapter.update!(collects_payout_details: true)

      get caregiver_root_path
      assert_select ".field-error", "We need this before your share can be sent."
      assert_select "a[href=?]", caregiver_intake_payout_path, text: "Set it up"

      patch caregiver_intake_payout_path, params: { payout: {
        payout_method: "gift_card", agreed: "1", street_line_1: "88 Magnolia Court", city: "Jonesboro", zipcode: "30236"
      } }

      assert_redirected_to caregiver_root_path
      assert @household.reload.payout_via_gift_card?
      assert @enrollment.reload.spending_agreed?
    end
  end
end
