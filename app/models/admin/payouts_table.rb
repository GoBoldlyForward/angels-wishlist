# frozen_string_literal: true

module Admin
  # The payout run as an index: one row per household, whether or not its payout is built.
  class PayoutsTable < Table
    # What Household#payout_blocker would say, for a household whose payout is not built yet.
    WOULD_BE = <<~SQL.squish
      CASE WHEN households.verification_status = 'hold' THEN 'held'
           WHEN households.verification_status <> 'verified' OR households.payout_method = 'none'
             OR (households.payout_method = 'stripe' AND households.stripe_onboarded_at IS NULL)
             OR (households.payout_method = 'gift_card' AND households.mailing_address_id IS NULL) THEN 'blocked'
           ELSE 'scheduled' END
    SQL
    STATUS = "COALESCE(payouts.status, #{WOULD_BE})".freeze
    METHOD = "COALESCE(payouts.method, households.payout_method)"

    attr_reader :event, :run

    def initialize(event, params)
      @event = event
      @run = PayoutRun.new(event)
      super(households, params, tabs: run_tabs, filters: run_filters, sorts: run_sorts,
            search: method(:matching), default_order: Arel.sql("households.display_name"))
    end

    def csv_columns
      {
        "Household" => ->(household) { household.display_name },
        "Caregiver" => ->(household) { household.caregiver.full_name },
        "Children" => ->(household) { run.row_for(household).children.join(", ") },
        "Asked" => ->(household) { Dollars.from_cents(run.row_for(household).asked_in_cents) },
        "Share" => ->(household) { Dollars.from_cents(run.row_for(household).share_in_cents) },
        "Payout" => ->(household) { Dollars.from_cents(run.row_for(household).amount_in_cents) },
        "Method" => ->(household) { run.row_for(household).method_label },
        "Destination" => ->(household) { run.row_for(household).destination },
        "Status" => ->(household) { run.row_for(household).status },
        "Blocker" => ->(household) { run.row_for(household).blocker }
      }
    end

    private

    def households
      Household.where(id: run.household_ids).joins(:caregiver).preload(:caregiver)
               .joins("LEFT JOIN payouts ON payouts.household_id = households.id AND payouts.deleted_at IS NULL " \
                      "AND payouts.event_id = #{event.id.to_i}")
               .joins("LEFT JOIN (#{asked.to_sql}) asked ON asked.household_id = households.id")
    end

    def asked
      LineItem.listed.joins(wishlist: :child).where(wishlist_id: event.counted_wishlists.select(:id))
              .group("children.household_id")
              .select("children.household_id", "SUM(line_items.price_in_cents) AS asked_in_cents")
    end

    def run_tabs
      [ Tab.new(key: "all", label: "All") ] +
        [ %w[scheduled Scheduled], %w[blocked Blocked], [ "held", "On hold" ], %w[failed Failed], %w[sent Sent],
          %w[delivered Delivered] ].map do |status, label|
          Tab.new(key: status, label: label, scope: ->(rows) { rows.where("#{STATUS} = ?", status) },
                  tone: ("danger" if status == "failed"))
        end
    end

    def run_filters
      [
        Filter.new(key: "method", label: "Method",
                   options: PayoutRun::METHOD_LABELS.invert.merge("Not set up" => "none"),
                   scope: ->(rows, value) { rows.where("#{METHOD} = ?", value) }),
        Filter.new(key: "county", label: "County", options: Household::COUNTIES.index_with(&:itself),
                   scope: ->(rows, value) { rows.where(county: value) }),
        Filter.new(key: "built", label: "Payout", options: { "Built" => "yes", "Not built yet" => "no" },
                   scope: ->(rows, value) { rows.where("payouts.id IS #{value == 'yes' ? 'NOT NULL' : 'NULL'}") })
      ]
    end

    def run_sorts
      [
        Sort.new(key: "household", label: "Household", order: "households.display_name"),
        Sort.new(key: "asked", label: "Asked", order: "COALESCE(asked.asked_in_cents, 0)"),
        Sort.new(key: "method", label: "Method", order: METHOD),
        Sort.new(key: "status", label: "Status", order: STATUS)
      ]
    end

    def matching(rows, query)
      like = "%#{Household.sanitize_sql_like(query)}%"
      rows.where("households.display_name ILIKE :like OR households.county ILIKE :like OR users.email ILIKE :like " \
                 "OR #{DonorType::NAME_SQL} ILIKE :like", like: like)
    end
  end
end
