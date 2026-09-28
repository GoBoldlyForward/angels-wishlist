# frozen_string_literal: true

require "test_helper"

module Admin
  class HouseholdsTableTest < ActiveSupport::TestCase
    setup do
      @chapter = build_organization
      @event = build_event(organization: @chapter)
      @household = build_household(organization: @chapter)
      @lists = Array.new(2) { build_wishlist(child: build_child(household: @household), event: @event) }
      @lists.each { |list| build_line_item(wishlist: list, price_in_cents: 10_000) }
    end

    test "a row carries the household's children and what its lists asked and were chosen for" do
      @lists.first.line_items.first.fund!(build_donation(event: @event, gift_in_cents: 10_000))
      build_wishlist(child: build_child(household: @household), event: @event, status: "withdrawn")
             .then { |list| build_line_item(wishlist: list, price_in_cents: 5_000) }

      row = table.rows.sole

      assert_equal 3, row.children_count
      assert_equal 20_000, row.asked_cents
      assert_equal 10_000, row.chosen_cents
    end

    test "a household's share matches what the model computes" do
      build_donation(event: @event, gift_in_cents: 0, general_gift_in_cents: 5_000)
      other = build_household(organization: @chapter)
      build_line_item(wishlist: build_wishlist(child: build_child(household: other), event: @event), price_in_cents: 20_000)

      households = table
      assert_equal @household.share_in_cents(@event), households.share_for(@household)
      assert_equal 5_000, households.share_for(@household) + households.share_for(other)
    end

    test "the payout status follows the household and then its payout" do
      unverified = build_household(organization: @chapter, verification_status: "pending")
      no_method = build_household(organization: @chapter, payout_method: "none")
      Payout.create!(household: @household, event: @event, status: "sent", amount_in_cents: 100)

      households = table
      assert_equal :sent, households.payout_status_for(@household)
      assert_equal :blocked, households.payout_status_for(unverified)
      assert_equal :nomethod, households.payout_status_for(no_method)
      assert_equal :scheduled, households.payout_status_for(build_household(organization: @chapter))
    end

    test "the summary counts who can be paid" do
      build_household(organization: @chapter, verification_status: "pending")
      build_household(organization: @chapter, payout_method: "gift_card", stripe_account_id: nil)

      assert_equal({ households: 3, children: 2, verified: 2, payable: 1 }, table.summary)
    end

    test "sorting by share puts a household outside the pool last" do
      build_donation(event: @event, gift_in_cents: 0, general_gift_in_cents: 5_000)
      pending = build_household(organization: @chapter, verification_status: "pending")
      build_line_item(wishlist: build_wishlist(child: build_child(household: pending), event: @event, status: "in_review"),
                      price_in_cents: 20_000)

      assert_equal [ @household, pending ], table(sort: "share", dir: "desc").rows.to_a
    end

    private

    def table(params = {})
      HouseholdsTable.new(@chapter, @event, ActionController::Parameters.new(params))
    end
  end
end
