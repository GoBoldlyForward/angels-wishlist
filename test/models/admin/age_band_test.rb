# frozen_string_literal: true

require "test_helper"

module Admin
  class AgeBandTest < ActiveSupport::TestCase
    test "a band holds a child from the youngest birthday through the day before they age out" do
      today = Date.new(2026, 11, 18)
      range = AgeBand.birthdates("6-11", today)

      assert_includes range, Date.new(2020, 11, 18)
      assert_not_includes range, Date.new(2020, 11, 19)
      assert_includes range, Date.new(2014, 11, 19)
      assert_not_includes range, Date.new(2014, 11, 18)
    end

    test "narrowing keeps the children whose age falls in the band" do
      event = build_event
      household = build_household(organization: event.organization)
      six = build_wishlist(child: build_child(household: household, age: 6), event: event)
      build_wishlist(child: build_child(household: household, age: 12), event: event)

      assert_equal [ six ], AgeBand.narrow(Wishlist.joins(:child), "6-11").to_a
    end
  end
end
