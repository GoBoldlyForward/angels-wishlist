# frozen_string_literal: true

require "test_helper"

class EnrollmentTest < ActiveSupport::TestCase
  setup do
    @household = build_household(payout_method: "none")
    @event = build_event(organization: @household.organization, love_box_options: LoveBox::DEFAULT_GROUPS)
    @enrollment = Enrollment.create!(household: @household, event: @event)
  end

  test "a new enrollment says everything that is missing" do
    assert_equal [ "Add at least one child.", "Finish your Love Box.", "Add at least one gift to every list.",
                   "Choose how you would like to be paid.", "Agree to how the funds will be spent." ],
                 @enrollment.blockers
  end

  test "submitting sends every draft list for review" do
    wishlist = build_wishlist(child: build_child(household: @household), event: @event, status: "draft")
    build_line_item(wishlist: wishlist)

    @enrollment.submit!

    assert @enrollment.submitted?
    assert_equal "in_review", wishlist.reload.status
  end

  test "intake only moves forward" do
    @enrollment.advance_to!(:lists)
    @enrollment.advance_to!(:children)

    assert_equal "lists", @enrollment.intake_step
    assert_equal 4, @enrollment.step_number
  end

  test "one enrollment per household per event" do
    assert_not Enrollment.new(household: @household, event: @event).valid?
  end

  test "a full Love Box is complete" do
    box = @enrollment.love_box_selection
    box.assign(box.groups.to_h { |group| [ group.id, { picks: [ group.options.first ], count: 2 } ] })

    assert box.complete?
    assert_equal "One holiday mug per caregiver (2)", box.summary_for(box.groups.find { |g| g.id == "cups" })
  end

  test "cups need a count unless declined" do
    box = @enrollment.love_box_selection
    choices = box.groups.to_h { |group| [ group.id, { picks: [ group.options.first ] } ] }
    box.assign(choices)
    assert_equal [ "cups" ], box.missing_groups.map(&:id)

    box.assign(choices.merge("cups" => { picks: [ LoveBox::DECLINED ] }))
    assert box.complete?
  end

  test "a second treat is only for more than five children" do
    box = @enrollment.love_box_selection
    treat = box.groups.find { |group| group.id == "treat" }
    snack = box.groups.find { |group| group.id == "snack" }
    assert_equal 1, box.picks_allowed(treat)
    assert_equal 2, box.picks_allowed(snack)

    6.times { build_child(household: @household) }
    assert_equal 2, LoveBox.new(@enrollment.reload).picks_allowed(treat)
  end

  test "a pick the event does not offer is dropped" do
    box = @enrollment.love_box_selection
    box.assign("drink" => { picks: [ "Espresso" ] })

    assert_empty box.picks_for(box.groups.find { |group| group.id == "drink" })
  end

  test "the packing list totals every submitted box" do
    2.times do
      household = build_household(organization: @household.organization)
      enrollment = Enrollment.create!(household: household, event: @event, submitted_at: Time.current)
      box = enrollment.love_box_selection
      box.assign("drink" => { picks: [ "Hot chocolate" ] }, "cups" => { picks: [ "One holiday mug per caregiver" ], count: 2 })
      enrollment.save!
    end

    totals = LoveBox.totals(@event)
    assert_equal 2, totals[[ "Family drink", "Hot chocolate" ]]
    assert_equal 4, totals[[ "Festive cups", "One holiday mug per caregiver" ]]
  end
end
