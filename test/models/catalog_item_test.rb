# frozen_string_literal: true

require "test_helper"

class CatalogItemTest < ActiveSupport::TestCase
  test "a typed gift only joins a tile on an unambiguous match" do
    item = build_catalog_item(name: "Winter coat")

    assert_equal item, CatalogItem.unambiguous_match("winter coat")
    assert_equal item, CatalogItem.unambiguous_match("  Winter Coat  ")
    assert_nil CatalogItem.unambiguous_match("graphing calculator")
  end

  test "two catalog items of the same name match neither" do
    build_catalog_item(name: "Hoodie")
    build_catalog_item(name: "Hoodie")

    assert_nil CatalogItem.unambiguous_match("hoodie")
  end

  test "age range brackets who the gift suits" do
    item = build_catalog_item(min_age: 5, max_age: 14)

    assert item.suits_age?(9)
    assert_not item.suits_age?(3)
    assert_not item.suits_age?(17)
  end

  test "an open ended age range suits everyone" do
    assert build_catalog_item(min_age: nil, max_age: nil).suits_age?(2)
  end

  test "a max age below the minimum is rejected" do
    item = CatalogItem.new(category: Category.create!(name: "Toys"), name: "Backwards",
                           price_in_cents: 100, min_age: 14, max_age: 5)

    assert_not item.valid?
  end
end
