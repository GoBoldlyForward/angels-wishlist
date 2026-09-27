# frozen_string_literal: true

module Admin
  # One event's payouts, built or not: every household with a counted list,
  # what it asked for, and its share of the pool.
  class PayoutRun
    METHOD_LABELS = { "stripe" => "Direct deposit", "gift_card" => "Mailed gift card" }.freeze

    Row = Data.define(:household, :payout, :lists, :share_in_cents) do
      def children
        lists.map(&:child_name)
      end

      def asked_in_cents
        lists.sum(&:asked_in_cents)
      end

      def amount_in_cents
        payout ? payout.amount_in_cents : share_in_cents
      end

      def status
        return payout.status if payout
        return "held" if household.verification_hold?

        household.payout_blocker ? "blocked" : "scheduled"
      end

      def method_label
        key = payout&.method || household.payout_method
        METHOD_LABELS.fetch(key, "Not set up")
      end

      def destination
        return payout.destination if payout

        household.payout_via_stripe? ? household.stripe_account_id : household.mailing_address&.to_s
      end

      def blocker
        return nil if settled?
        return payout.hold_reason if payout&.failed?

        household.payout_blocker
      end

      def dispatch
        PayoutDispatch.new(payout, share_in_cents: share_in_cents)
      end

      def built?
        payout.present?
      end

      def sendable?
        built? && dispatch.sendable?
      end

      def settled?
        payout.present? && (payout.sent? || payout.delivered?)
      end

      # Built before the pool or the household changed, so its amount is no longer the share.
      def stale?
        built? && !settled? && payout.amount_in_cents != share_in_cents
      end
    end

    List = Data.define(:wishlist_id, :child_name, :asked_in_cents, :share_in_cents)

    attr_reader :event

    def initialize(event)
      @event = event
    end

    def rows
      @rows ||= households.map do |household|
        mine = lists.fetch(household.id, [])
        Row.new(household: household, payout: payouts[household.id], lists: mine,
                share_in_cents: mine.sum(&:share_in_cents))
      end
    end

    def row_for(household)
      rows_by_household.fetch(household.id)
    end

    def household_ids
      (lists.keys + payouts.keys).uniq
    end

    def raised_in_cents
      @raised_in_cents ||= event.raised_in_cents
    end

    def asked_in_cents
      @asked_in_cents ||= event.goal_in_cents
    end

    def pool_in_cents
      [ raised_in_cents, asked_in_cents ].min
    end

    def surplus_in_cents
      [ raised_in_cents - asked_in_cents, 0 ].max
    end

    def funded_percent
      (event.funded_ratio * 100).to_f.round(1)
    end

    def total_in_cents
      rows.sum(&:amount_in_cents)
    end

    def scheduled_in_cents
      rows.select { |row| row.status == "scheduled" }.sum(&:amount_in_cents)
    end

    def sent_in_cents
      rows.select(&:settled?).sum(&:amount_in_cents)
    end

    def blocked_count
      rows.count { |row| %w[blocked held].include?(row.status) }
    end

    def unbuilt_count
      rows.count { |row| !row.built? }
    end

    def stale_count
      rows.count(&:stale?)
    end

    def difference_in_cents
      pool_in_cents - total_in_cents
    end

    def built?
      rows.any?(&:built?)
    end

    def balanced?
      difference_in_cents.zero?
    end

    def current?
      unbuilt_count.zero? && stale_count.zero?
    end

    private

    def rows_by_household
      @rows_by_household ||= rows.index_by { |row| row.household.id }
    end

    def households
      Household.where(id: household_ids).preload(:caregiver, :mailing_address).order(:display_name)
    end

    # Payouts share this run's event and households, so reading one never queries again.
    def payouts
      @payouts ||= event.payouts.preload(:mailing_address, household: %i[caregiver mailing_address])
                        .each { |payout| payout.association(:event).target = event }
                        .index_by(&:household_id)
    end

    def lists
      @lists ||= begin
        counted = event.counted_wishlists.pluck("wishlists.id", "children.household_id", "children.display_name")
        asked = LineItem.listed.where(wishlist_id: counted.map(&:first)).group(:wishlist_id).sum(:price_in_cents)
        counted.each_with_object({}) do |(id, household_id, child_name), by_household|
          (by_household[household_id] ||= []) << List.new(wishlist_id: id, child_name: child_name,
                                                          asked_in_cents: asked.fetch(id, 0),
                                                          share_in_cents: event.shares.fetch(id, 0))
        end
      end
    end
  end
end
