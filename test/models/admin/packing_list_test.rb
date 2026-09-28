# frozen_string_literal: true

require "test_helper"

module Admin
  class PackingListTest < ActiveSupport::TestCase
    setup do
      @chapter = build_organization
      @event = build_event(organization: @chapter, love_box_options: LoveBox::DEFAULT_GROUPS)
      @first = box_for("The Brooks home", "drink" => { "picks" => [ "Hot chocolate" ] },
                                          "snack" => { "picks" => [ "Boxed candy", "Microwave popcorn (box)" ] })
      @second = box_for("The Alvarez home", "drink" => { "picks" => [ "Hot chocolate" ] },
                                            "cozy" => { "picks" => [ LoveBox::DECLINED ] })
    end

    test "totals are grouped by label in the order the event lists its groups" do
      totals = PackingList.new(@event).totals

      assert_equal [ "Family drink", "Family snack" ], totals.keys
      assert_equal({ "Hot chocolate" => 2 }, totals["Family drink"])
      assert_equal({ "Boxed candy" => 1, "Microwave popcorn (box)" => 1 }, totals["Family snack"])
    end

    test "boxes come in household order with a count of active children" do
      build_child(household: @first.household)
      build_child(household: @first.household, archived_at: Time.current)

      boxes = PackingList.new(@event).boxes

      assert_equal [ "The Alvarez home", "The Brooks home" ], boxes.map { |box| box.household.display_name }
      assert_equal [ 0, 1 ], boxes.map(&:children_count)
    end

    test "a household that has not submitted is left off" do
      @second.update!(submitted_at: nil)

      list = PackingList.new(@event)

      assert_equal [ "The Brooks home" ], list.boxes.map { |box| box.household.display_name }
      assert_equal({ "Hot chocolate" => 1 }, list.totals["Family drink"])
    end

    test "without an event there is nothing to pack" do
      list = PackingList.new(nil)

      assert_empty list.boxes
      assert_empty list.totals
      assert_equal 1, list.to_csv.lines.size
    end

    private

    def box_for(name, picks)
      household = build_household(organization: @chapter, display_name: name)
      enrollment = Enrollment.new(household: household, event: @event, submitted_at: Time.current)
      enrollment.love_box_selection.assign(picks)
      enrollment.tap(&:save!)
    end
  end
end
