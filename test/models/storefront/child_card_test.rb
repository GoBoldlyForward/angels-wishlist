# frozen_string_literal: true

require "test_helper"

module Storefront
  class ChildCardTest < ActiveSupport::TestCase
    PRIVATE_RECORDS = [ Child, Household, Wishlist, LineItem, Donation, User, Address ].freeze

    setup do
      @household = build_household(county: "Fulton County")
      child = build_child(household: @household, age: 9, gender: "girl", display_name: "Maya",
                          legal_first_name: "Zephyrine")
      @wishlist = build_wishlist(child: child, interests: %w[drawing soccer], approved_at: 2.days.ago,
                                 caregiver_note: "She draws on every page she can find.")
      @coat = build_line_item(wishlist: @wishlist, name: "Winter coat", price_in_cents: 6_000)
      @book = build_line_item(wishlist: @wishlist, name: "Book set", price_in_cents: 2_000, spec: "Hardcover")
    end

    test "it carries the alias, age, gender, county, interests, note, and gifts" do
      card = ChildCard.new(@wishlist, lines: [ @coat, @book ])

      assert_equal "Maya", card.alias_name
      assert_equal 9, card.age
      assert_equal "girl", card.gender
      assert_equal "Fulton County", card.county
      assert_equal %w[drawing soccer], card.interests
      assert_equal "She draws on every page she can find.", card.note
      assert_equal [ "Winter coat", "Book set" ], card.gifts.map(&:name)
      assert_equal "Maya, 9", card.to_s
      assert_equal "Girl · Fulton County", card.meta
    end

    test "its public surface is a fixed list, so a new field is a decision and not an accident" do
      assert_equal %i[age alias_name asked_in_cents chosen_in_cents complete? county gender gender_label gifts
                      in_cart interests key left left_in_cents meta new_this_week? note percent_chosen teen?
                      to_s untouched?],
                   ChildCard.public_instance_methods(false).sort
      assert_equal %i[available? catalog_item category child chosen_by funded? in_cart? key link_host link_url
                      name pooled? price_in_cents product_key product_name spec waiting_order],
                   Gift.public_instance_methods(false).sort
    end

    test "it holds values, never the records they came from" do
      card = ChildCard.new(@wishlist, lines: [ @coat, @book ])

      ([ card ] + card.gifts).each do |presenter|
        held = presenter.instance_variables.map { |name| presenter.instance_variable_get(name) }
        assert_empty held.select { |value| PRIVATE_RECORDS.any? { |record| value.is_a?(record) } }
      end
    end

    test "progress counts gifts chosen against gifts asked, by dollars" do
      @book.fund!(build_donation(event: @wishlist.event, gift_in_cents: 2_000))
      card = ChildCard.new(@wishlist.reload, lines: @wishlist.line_items.oldest_first.to_a)

      assert_equal 8_000, card.asked_in_cents
      assert_equal 2_000, card.chosen_in_cents
      assert_equal 25, card.percent_chosen
      assert_equal [ "Winter coat" ], card.left.map(&:name)
      assert_not card.complete?
      assert_not card.untouched?
    end

    test "a gift in the visitor's cart is not left to add and not yet chosen" do
      card = ChildCard.new(@wishlist, lines: [ @coat, @book ], cart_ids: [ @coat.id ])

      assert_equal [ "Book set" ], card.left.map(&:name)
      assert_equal [ "Winter coat" ], card.in_cart.map(&:name)
      assert_equal 0, card.chosen_in_cents
    end

    test "a funded gift names the donor only the way they asked to be shown" do
      donor = build_donor(first_name: "Priya", last_name: "Sundaram")
      @coat.fund!(build_donation(event: @wishlist.event, donor: donor, display_name: nil, anonymous: false))
      @book.fund!(build_donation(event: @wishlist.event, donor: donor, display_name: "Priya S.", anonymous: true))
      named = build_line_item(wishlist: @wishlist, name: "Puzzle", price_in_cents: 1_500)
      named.fund!(build_donation(event: @wishlist.event, display_name: "The Hollis family"))

      card = ChildCard.new(@wishlist, lines: [ @coat.reload, @book.reload, named.reload ])

      assert_equal [ "Anonymous", "Anonymous", "The Hollis family" ], card.gifts.map(&:chosen_by)
    end

    test "a list is new for seven days after it is approved" do
      assert ChildCard.new(@wishlist).new_this_week?

      @wishlist.update_column(:approved_at, 8.days.ago)

      assert_not ChildCard.new(@wishlist.reload).new_this_week?
    end

    test "a link is kept only when it is a web address" do
      @coat.update_column(:link_url, "javascript:alert(1)")
      @book.update_column(:link_url, "https://www.example.com/books?id=4")
      card = ChildCard.new(@wishlist, lines: [ @coat, @book ])

      assert_nil card.gifts.first.link_url
      assert_equal "example.com", card.gifts.last.link_host
    end
  end
end
