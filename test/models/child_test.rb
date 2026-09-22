# frozen_string_literal: true

require "test_helper"

class ChildTest < ActiveSupport::TestCase
  test "age reads off the birthdate" do
    assert_equal 9, build_child(age: 9).age
  end

  test "age is nil without a birthdate" do
    assert_nil build_child(birthdate: nil).age
  end

  test "a birthday still to come this year has not counted yet" do
    child = build_child(birthdate: Date.current.advance(years: -10, days: 30))
    assert_equal 9, child.age
  end

  test "to_s names the child and the age a donor sees" do
    assert_equal "Maya, 9", build_child(age: 9).to_s
  end
end
