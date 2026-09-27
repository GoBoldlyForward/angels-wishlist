# frozen_string_literal: true

require "test_helper"

module Storefront
  class CatalogTest < ActiveSupport::TestCase
    setup do
      @event = build_event
      @household = build_household(organization: @event.organization)
      @hoodie = build_catalog_item(name: "Hoodie", price_in_cents: 4_000)
      @bike = build_catalog_item(name: "Bike", price_in_cents: 15_000)
    end

    test "lines for the same catalog item share one product" do
      list("Maya", 9, @hoodie, @bike)
      list("Theo", 14, @hoodie)

      products = catalog.products

      assert_equal [ "Hoodie", "Bike" ], products.map(&:name)
      assert_equal 2, products.first.left.size
    end

    test "a custom line is a product of its own, even beside one with the same name" do
      maya = list("Maya", 9)
      theo = list("Theo", 14)
      build_line_item(wishlist: maya, name: "Purple scooter", price_in_cents: 3_500)
      build_line_item(wishlist: theo, name: "Purple scooter", price_in_cents: 3_500)

      products = catalog.custom_products

      assert_equal 2, products.size
      assert_equal [ "#{maya.slug}--purple-scooter", "#{theo.slug}--purple-scooter" ], products.map(&:key)
      assert products.all?(&:custom?)
      assert_equal 1, catalog.product("#{maya.slug}--purple-scooter").gifts.size
    end

    test "a product splits what is left into the pool and the specific requests" do
      list("Maya", 9, @hoodie)
      specific = list("Theo", 14)
      build_line_item(wishlist: specific, catalog_item: @hoodie, name: "Hoodie", price_in_cents: 4_500,
                      spec: "Nike, size L")

      product = catalog.product(@hoodie.slug)

      assert_equal [ "Maya" ], product.pooled_left.map { |gift| gift.child.alias_name }
      assert_equal [ "Nike, size L" ], product.specific_left.map(&:spec)
      assert product.varied_prices?
      assert_equal 4_000, product.lowest_price_in_cents
    end

    test "a product with everything funded keeps its price and is done" do
      wishlist = list("Maya", 9, @hoodie)
      wishlist.line_items.first.fund!(build_donation(event: @event, display_name: "The Reyes family"))

      product = catalog.product(@hoodie.slug)

      assert product.done?
      assert_equal 4_000, product.lowest_price_in_cents
      assert_equal [ "The Reyes family" ], product.chosen_by
    end

    test "the shelves follow the prototype's rules" do
      almost = list("Maya", 9, @hoodie, @bike)
      almost.line_items.find_by(catalog_item: @bike).fund!(build_donation(event: @event))
      list("Theo", 14, @hoodie, @bike)
      list("Nova", 6, @bike, approved_at: 1.day.ago)

      shelves = catalog

      assert_equal [ "Maya" ], shelves.almost_finished.map { |gift| gift.child.alias_name }.sort - [ "Nova" ]
      assert_equal %w[Nova Theo], shelves.untouched.map(&:alias_name).sort
      assert_equal [ "Hoodie" ], shelves.under_forty.map(&:name)
      assert_equal [ "Theo" ], shelves.teenagers.map(&:alias_name)
      assert_equal [ "Nova" ], shelves.new_this_week.map(&:alias_name)
    end

    test "gifts in the visitor's cart stop counting as left" do
      wishlist = list("Maya", 9, @hoodie)
      list("Theo", 14, @hoodie)

      product = catalog(cart_ids: wishlist.line_items.pluck(:id)).product(@hoodie.slug)

      assert_equal [ "Theo" ], product.left.map { |gift| gift.child.alias_name }
      assert_equal [ "Maya" ], product.carted.map { |gift| gift.child.alias_name }
      assert_equal 2, product.open.size
    end

    test "only lists donors may see are loaded" do
      list("Maya", 9, @hoodie)
      list("Theo", 14, @hoodie, status: "in_review")
      list("Nova", 6, @hoodie, household: build_household(organization: @event.organization,
                                                          verification_status: "pending"))
      list("Sage", 7, @hoodie, event: build_event)

      assert_equal [ "Maya" ], catalog.children.map(&:alias_name)
      assert_equal 1, Catalog.shoppable_lines(@event).count
    end

    test "with no event there is nothing to show" do
      assert Catalog.new(event: nil).empty?
      assert_empty Catalog.shoppable_lines(nil)
    end

    private

    def catalog(cart_ids: [])
      Catalog.new(event: @event, cart_ids: cart_ids)
    end

    def list(name, age, *items, household: @household, status: "live", event: @event, approved_at: 3.weeks.ago)
      child = build_child(household: household, display_name: name, age: age)
      wishlist = build_wishlist(child: child, event: event, status: status, approved_at: approved_at)
      items.each_with_index do |item, index|
        build_line_item(wishlist: wishlist, catalog_item: item, name: item.name,
                        price_in_cents: item.price_in_cents, created_at: (10 - index).days.ago)
      end
      wishlist
    end
  end
end
