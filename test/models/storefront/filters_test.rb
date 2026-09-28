# frozen_string_literal: true

require "test_helper"

module Storefront
  class FiltersTest < ActiveSupport::TestCase
    Child = Struct.new(:gender, :age)
    Gift = Struct.new(:child, :price_in_cents)

    test "with nothing chosen everything matches" do
      filters = Filters.new

      assert_not filters.any?
      assert filters.matches?(Gift.new(Child.new("boy", 4), 9_900))
      assert_empty filters.to_h
    end

    test "a value that is not on the list is ignored" do
      filters = Filters.new(gender: "anything", age: "99", price: "free")

      assert_not filters.any?
    end

    test "gender and age are read off the child" do
      filters = Filters.new(gender: "girl", age: "6-9")

      assert filters.matches_child?(Child.new("girl", 9))
      assert_not filters.matches_child?(Child.new("girl", 10))
      assert_not filters.matches_child?(Child.new("boy", 7))
      assert_not filters.matches_child?(Child.new("girl", nil))
    end

    test "the oldest band has no upper edge" do
      assert Filters.new(age: "13-18").matches_child?(Child.new("boy", 19))
    end

    test "price bands include both of their edges" do
      gift = ->(cents) { Gift.new(Child.new("girl", 9), cents) }

      assert Filters.new(price: "u25").matches?(gift.call(2_500))
      assert_not Filters.new(price: "u25").matches?(gift.call(2_501))
      assert Filters.new(price: "25-50").matches?(gift.call(2_500))
      assert Filters.new(price: "25-50").matches?(gift.call(5_000))
      assert_not Filters.new(price: "50-100").matches?(gift.call(4_999))
      assert Filters.new(price: "100+").matches?(gift.call(10_000))
    end

    test "a pill links to the same filters with one changed" do
      filters = Filters.new(gender: "girl", price: "u25")

      assert_equal({ gender: "girl", price: "u25", age: "6-9" }, filters.with(:age, "6-9"))
      assert_equal({ price: "u25" }, filters.with(:gender, nil))
      assert_equal "A girl", filters.label(filters.groups.first)
      assert_equal "Any age", filters.label(filters.groups.second)
    end

    test "any? can look at only the filters a page offers" do
      filters = Filters.new(price: "u25")

      assert filters.any?
      assert_not filters.any?(only: %i[gender age])
    end
  end
end
