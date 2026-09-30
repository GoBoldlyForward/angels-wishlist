# frozen_string_literal: true

require "test_helper"

module Storefront
  class CartTest < ActiveSupport::TestCase
    setup do
      @event = build_event
      @household = build_household(organization: @event.organization)
      @item = build_catalog_item(name: "Hoodie", price_in_cents: 4_000)
      @session = {}
      @cart = Cart.new(@session, event: @event)
    end

    test "pooled gifts go in oldest first" do
      newest = ask("Maya", days_ago: 1)
      oldest = ask("Theo", days_ago: 20)
      middle = ask("Nova", days_ago: 10)

      assert_equal 2, @cart.add_pooled(@item, 2)
      assert_equal [ oldest.id, middle.id ], @cart.line_item_ids

      assert_equal 1, @cart.add_pooled(@item, 5)
      assert_equal [ oldest.id, middle.id, newest.id ], @cart.line_item_ids
    end

    test "pooled gifts never include a request that names a brand or size" do
      ask("Maya", days_ago: 30, spec: "Nike, size L")
      pooled = ask("Theo", days_ago: 2)

      @cart.add_pooled(@item, 3)

      assert_equal [ pooled.id ], @cart.line_item_ids
    end

    test "a quantity of nothing, or less, adds nothing" do
      ask("Maya", days_ago: 3)

      assert_equal 0, @cart.add_pooled(@item, 0)
      assert_equal 0, @cart.add_pooled(@item, -4)
      assert_equal 0, @cart.add_pooled(@item, "lots")
      assert_empty @cart.line_item_ids
    end

    test "only lines a donor may fund right now get in" do
      funded = ask("Maya", days_ago: 9)
      funded.fund!(build_donation(event: @event))
      waiting = ask("Theo", days_ago: 8, status: "needs_review")
      unverified = ask("Nova", days_ago: 7, household: build_household(organization: @event.organization,
                                                                       verification_status: "pending"))
      in_review = ask("Sage", days_ago: 6, list_status: "in_review")
      other_event = build_line_item(wishlist: build_wishlist(event: build_event), catalog_item: @item)

      [ funded, waiting, unverified, in_review, other_event ].each do |line|
        assert_equal 0, @cart.add_gift(key_for(line))
      end
      assert_equal 0, @cart.add_pooled(@item, 10)
      assert_empty @cart.line_item_ids
    end

    test "the same gift cannot be added twice" do
      line = ask("Maya", days_ago: 3)

      assert_equal 1, @cart.add_gift(key_for(line))
      assert_equal 0, @cart.add_gift(key_for(line))
      assert_equal [ line.id ], @cart.line_item_ids
    end

    test "totals keep gifts, general gifts, and the fee apart" do
      @cart.add_gift(key_for(ask("Maya", days_ago: 3)))
      @cart.add_general_gift(2_500)

      assert_equal 4_000, @cart.gift_in_cents
      assert_equal 2_500, @cart.general_gift_in_cents
      assert_equal 6_500, @cart.total_in_cents
      assert_equal 225, @cart.fee_in_cents
      assert_equal 2, @cart.count
    end

    test "a general gift is five dollars or more, typed in dollars" do
      assert_not @cart.add_general_gift_in_dollars("4.99")
      assert_not @cart.add_general_gift_in_dollars("NaN")
      assert_not @cart.add_general_gift_in_dollars("1e12")
      assert @cart.add_general_gift_in_dollars("5")
      assert @cart.add_general_gift_in_dollars("$1,250.50")

      assert_equal [ 500, 125_050 ], @cart.general_gifts
    end

    test "a line that closed since it was added is dropped and counted" do
      kept = ask("Maya", days_ago: 3)
      gone = ask("Theo", days_ago: 2)
      @cart.add_gift(key_for(kept))
      @cart.add_gift(key_for(gone))
      gone.fund!(build_donation(event: @event))

      cart = Cart.new(@session, event: @event)

      assert_equal [ kept ], cart.lines
      assert_equal 1, cart.dropped_count
      assert_equal [ kept.id ], @session["cart"]["line_item_ids"]
    end

    test "gifts are grouped by child for checkout" do
      maya = ask("Maya", days_ago: 3)
      theo = ask("Theo", days_ago: 2)
      second = build_line_item(wishlist: maya.wishlist, name: "Book set", price_in_cents: 1_500)
      [ maya, theo, second ].each { |line| @cart.add_gift(key_for(line)) }

      groups = @cart.gifts_by_child.map { |gifts| [ gifts.first.child.alias_name, gifts.map(&:name) ] }

      assert_equal [ [ "Maya", [ "Hoodie", "Book set" ] ], [ "Theo", [ "Hoodie" ] ] ], groups
    end

    test "clearing the cart empties the session" do
      @cart.add_general_gift(2_500)

      @cart.clear

      assert @cart.empty?
      assert_nil @session["cart"]
    end

    private

    def ask(name, days_ago:, household: @household, list_status: "live", **attrs)
      child = build_child(household: household, display_name: name)
      wishlist = build_wishlist(child: child, event: @event, status: list_status)
      build_line_item(wishlist: wishlist, catalog_item: @item, name: "Hoodie", price_in_cents: 4_000,
                      created_at: days_ago.days.ago, **attrs)
    end

    def key_for(line)
      line.signed_id(purpose: Gift::KEY_PURPOSE)
    end
  end
end
