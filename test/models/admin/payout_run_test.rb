# frozen_string_literal: true

require "test_helper"

module Admin
  class PayoutRunTest < ActiveSupport::TestCase
    setup do
      @chapter = build_organization
      @event = build_event(organization: @chapter)
      @brooks = household_asking(20_000, 10_000)
      @okafor = household_asking(3_333)
      @held = household_asking(7_001, verification_status: "hold", hold_reason: "Placement changed.")
      @pending = household_asking(15_000, verification_status: "pending")
      build_donation(event: @event, gift_in_cents: 0, general_gift_in_cents: 17_777)
    end

    test "the run holds every household with a counted list and leaves out an unverified one" do
      run = PayoutRun.new(@event)

      assert_equal [ @brooks, @okafor, @held ].map(&:id).sort, run.rows.map { |row| row.household.id }.sort
    end

    test "shares add up to the pool to the cent before anything is built" do
      run = PayoutRun.new(@event)

      assert_equal 17_777, run.pool_in_cents
      assert_equal 17_777, run.total_in_cents
      assert run.balanced?
      assert_not run.built?
      assert_equal 3, run.unbuilt_count
    end

    test "a household's share is the sum of its children's list shares" do
      row = PayoutRun.new(@event).row_for(@brooks)

      assert_equal 2, row.lists.size
      assert_equal 30_000, row.asked_in_cents
      assert_equal row.lists.sum(&:share_in_cents), row.share_in_cents
      assert_equal @brooks.share_in_cents(@event), row.share_in_cents
    end

    test "an unbuilt row reads its status off the household" do
      run = PayoutRun.new(@event)

      assert_equal "scheduled", run.row_for(@brooks).status
      assert_equal "held", run.row_for(@held).status
      assert_equal "Placement changed.", run.row_for(@held).blocker
      assert_equal 1, run.blocked_count
      assert_not run.row_for(@brooks).sendable?
    end

    test "a built run matches the pool and can be sent" do
      @event.build_payouts!
      run = PayoutRun.new(@event)

      assert run.built?
      assert run.current?
      assert run.balanced?
      assert run.row_for(@brooks).sendable?
      assert_not run.row_for(@held).sendable?
      assert_equal run.rows.reject { |row| row.status == "held" }.sum(&:amount_in_cents), run.scheduled_in_cents
    end

    test "a payout built before another gift arrived is stale and the run is out by that gift" do
      @event.build_payouts!
      build_donation(event: @event, gift_in_cents: 0, general_gift_in_cents: 1_000)
      run = PayoutRun.new(@event.reload)

      assert_equal 3, run.stale_count
      assert_equal 1_000, run.difference_in_cents
      assert_not run.balanced?
      assert_not run.row_for(@brooks).sendable?
    end

    test "giving beyond what every list asked is a surplus and lists stop at what they asked" do
      build_donation(event: @event, gift_in_cents: 0, general_gift_in_cents: 50_000)
      run = PayoutRun.new(@event)

      assert_equal 40_334, run.pool_in_cents
      assert_equal 27_443, run.surplus_in_cents
      assert_equal 100.0, run.funded_percent
      assert run.balanced?
    end

    test "the table's status for an unbuilt household agrees with the household's own blocker" do
      household_asking(5_000, payout_method: "none", stripe_account_id: nil)
      household_asking(5_000, stripe_account_id: nil)
      household_asking(5_000, payout_method: "gift_card", stripe_account_id: nil)
      table = PayoutsTable.new(@event, {})

      statuses = table.rows.pluck(:id, Arel.sql(PayoutsTable::STATUS)).to_h
      table.run.rows.each do |row|
        assert_equal row.status, statuses.fetch(row.household.id), row.household.payout_blocker
      end
      assert_equal 3, statuses.values.count("blocked")
    end

    private

    def household_asking(*amounts, **attrs)
      household = build_household(organization: @chapter, **attrs)
      amounts.each do |cents|
        wishlist = build_wishlist(child: build_child(household: household), event: @event)
        build_line_item(wishlist: wishlist, price_in_cents: cents)
      end
      household
    end
  end
end
