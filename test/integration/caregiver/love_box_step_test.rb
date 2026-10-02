# frozen_string_literal: true

require_relative "intake_test_case"

module Caregiver
  class LoveBoxStepTest < IntakeTestCase
    setup do
      @household, @enrollment = start_household(step: "love_box")
      add_child_with_list(@household)
      sign_in users(:caregiver)
    end

    test "every group is a list of options to click, with the disclosure beneath" do
      get caregiver_intake_love_box_path

      assert_response :success
      assert_select "select", 0
      assert_select "input[type=radio][name=?]", "love_box[holiday][picks][]", 4
      assert_select "input[type=checkbox][name=?]", "love_box[snack][picks][]", 3
      assert_select "input[type=radio][name=?]", "love_box[treat][picks][]", 3
      assert_select "fieldset legend", "Family drink"
      assert_select ".disclosure", /separate from the gift funds/
    end

    test "one craft kit is offered among two activities, and the box itself is not a choice" do
      get caregiver_intake_love_box_path

      assert_select "input[type=checkbox][name=?][value=?]", "love_box[activity][picks][]", "Family craft kit", 1
      assert_select "input[name=?]", "love_box[activity][picks][]", 6
      assert_select "fieldset legend", text: /container/i, count: 0
    end

    test "options read alphabetically with no thank you last, however the event lists them" do
      @event.update!(love_box_options: [ { id: "grocery", label: "$25 grocery gift card",
                                           options: [ "Walmart", "No thank you", "ALDI", "Trader Joe's" ] } ])

      get caregiver_intake_love_box_path

      assert_equal [ "ALDI", "Trader Joe's", "Walmart", "No thank you" ],
                   css_select("input[name='love_box[grocery][picks][]']").map { |input| input["value"] }
    end

    test "a household with more than five children picks two treats" do
      5.times { |number| add_child_with_list(@household, first_name: "Child #{number}") }

      get caregiver_intake_love_box_path

      assert_select "input[type=checkbox][name=?]", "love_box[treat][picks][]", 3
      assert_select ".hint", "Households with more than five kids pick two."
    end

    test "a full box is saved and leads to getting paid" do
      patch caregiver_intake_love_box_path, params: { love_box: full_love_box }

      assert_redirected_to caregiver_intake_payout_path
      box = @enrollment.reload.love_box_selection
      assert box.complete?
      assert_equal "Holiday plastic cups for each member of the family (2)", box.summary_for(box.groups.second)
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
