# frozen_string_literal: true

require_relative "intake_test_case"

module Caregiver
  class LoveBoxStepTest < IntakeTestCase
    setup do
      @household, @enrollment = start_household(step: "love_box")
      add_child_with_list(@household)
      sign_in users(:caregiver)
    end

    test "every group is one select, with the disclosure beneath" do
      get caregiver_intake_love_box_path

      assert_response :success
      assert_select "select[name^='love_box[']", @event.love_box_groups.size + 1
      assert_select "select[name=?]", "love_box[snack][picks][]", 2
      assert_select "select[name=?]", "love_box[treat][picks][]", 1
      assert_select ".disclosure", /separate from the gift funds/
    end

    test "a household with more than five children picks two treats" do
      5.times { |number| add_child_with_list(@household, first_name: "Child #{number}") }

      get caregiver_intake_love_box_path

      assert_select "select[name=?]", "love_box[treat][picks][]", 2
      assert_select ".hint", "Households with more than five kids pick two."
    end

    test "a full box is saved and leads to getting paid" do
      patch caregiver_intake_love_box_path, params: { love_box: full_love_box }

      assert_redirected_to caregiver_intake_payout_path
      box = @enrollment.reload.love_box_selection
      assert box.complete?
      assert_equal "One holiday mug per caregiver (2)", box.summary_for(box.groups.second)
      assert_equal "payout", @enrollment.intake_step
    end

    test "a half-finished box is saved and says what is missing" do
      patch caregiver_intake_love_box_path,
            params: { love_box: full_love_box.except("drink").merge("cups" => { picks: [ "One holiday mug per caregiver" ], count: "" }) }

      assert_response :unprocessable_entity
      assert_select ".form-errors", /2 choices still to make/
      assert_select ".field-error", "Choose one."
      assert_select ".field-error", "Tell us how many."
      assert_equal [ "Christmas" ], @enrollment.reload.love_box.dig("holiday", "picks")
      assert_equal "love_box", @enrollment.intake_step
    end

    test "an event with no Love Box choices lets the caregiver carry on" do
      @event.update!(love_box_options: [])

      get caregiver_intake_love_box_path
      assert_select ".panel", /nothing to choose for the Love Box yet/

      patch caregiver_intake_love_box_path
      assert_redirected_to caregiver_intake_payout_path
    end

    test "an option the event does not offer is dropped" do
      patch caregiver_intake_love_box_path,
            params: { love_box: full_love_box.merge("holiday" => { picks: [ "A pony" ] }) }

      assert_response :unprocessable_entity
      assert_empty @enrollment.reload.love_box.dig("holiday", "picks")
    end
  end
end
