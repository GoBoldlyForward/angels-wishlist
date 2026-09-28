# frozen_string_literal: true

module Admin
  # The Households index: every active household of the chapter, with what it
  # asked for and is owed in one event.
  class HouseholdsTable < Table
    PAYOUT_METHODS = { "Direct deposit" => "stripe", "Mailed gift card" => "gift_card", "Not set up" => "none" }.freeze
    SEARCHED = %w[households.display_name households.county users.first_name users.last_name users.email
                  users.phone organizations.name].freeze

    attr_reader :chapter, :event

    def initialize(chapter, event, params)
      @chapter = chapter
      @event = event
      super(households, params, tabs: build_tabs, filters: build_filters, sorts: build_sorts,
                                search: method(:matching), default_order: "households.display_name ASC")
    end

    def rows
      Figures.households(super, event).preload(:caregiver, :placing_organization, :mailing_address)
    end

    def summary
      @summary ||= begin
        all = households.preload(:mailing_address).to_a
        { households: all.size, children: Child.active.where(household_id: all.map(&:id)).count,
          verified: all.count(&:verification_verified?), payable: all.count(&:payable?) }
      end
    end

    def share_for(household)
      shares.fetch(household.id, 0)
    end

    # Household#payout_status, with the payout read from one query for the whole page.
    def payout_status_for(household)
      return household.payout_status(event) unless household.verification_verified? && !household.payout_via_none?

      payout_statuses.fetch(household.id, :scheduled)
    end

    def csv_columns
      {
        "Household" => ->(row) { row.display_name },
        "County" => ->(row) { row.county },
        "Caregiver" => ->(row) { row.caregiver&.full_name },
        "Email" => ->(row) { row.caregiver&.email },
        "Phone" => ->(row) { row.caregiver&.phone },
        "Agency" => ->(row) { row.placing_organization&.name },
        "Children" => ->(row) { row.children_count },
        "Asked" => ->(row) { row.asked_cents / 100.0 },
        "Chosen by donors" => ->(row) { row.chosen_cents / 100.0 },
        "Share" => ->(row) { share_for(row) / 100.0 },
        "Verification" => ->(row) { row.verification_status },
        "Payout method" => ->(row) { row.payout_method },
        "Payout status" => ->(row) { payout_status_for(row) },
        "Cannot be paid because" => ->(row) { row.payout_blocker }
      }
    end

    private

    def households
      Household.active.where(organization: chapter).left_joins(:caregiver, :placing_organization)
    end

    def returning
      earlier = Wishlist.joins(:child, :event).where(events: { organization_id: chapter&.id })
                        .where.not(events: { id: Event.open_now.select(:id) })
      Household.where(id: earlier.select("children.household_id"))
    end

    def matching(rows, query)
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      rows.where(SEARCHED.map { |column| "#{column} ILIKE :pattern" }.join(" OR "), pattern: pattern)
    end

    def shares
      @shares ||= if event
        Wishlist.where(id: event.shares.keys).joins(:child).pluck("children.household_id", :id)
                .each_with_object(Hash.new(0)) { |(household_id, id), sums| sums[household_id] += event.shares[id] }
      else
        {}
      end
    end

    def payout_statuses
      @payout_statuses ||= event ? event.payouts.pluck(:household_id, :status).to_h.transform_values(&:to_sym) : {}
    end

    def build_tabs
      [
        Tab.new(key: "all", label: "All"),
        Tab.new(key: "verified", label: "Verified", tone: "success", scope: ->(rows) { rows.verification_verified }),
        Tab.new(key: "pending", label: "Pending", tone: "warning", scope: ->(rows) { rows.verification_pending }),
        Tab.new(key: "hold", label: "On hold", tone: "danger", scope: ->(rows) { rows.verification_hold }),
        Tab.new(key: "nopay", label: "No payout method", tone: "warning", scope: ->(rows) { rows.payout_via_none }),
        Tab.new(key: "returning", label: "Returning", scope: ->(rows) { rows.merge(returning) })
      ]
    end

    def build_filters
      counties = households.unscope(:left_outer_joins).where.not(county: [ nil, "" ]).distinct.order(:county).pluck(:county)
      agencies = Organization.agency.where(id: households.select(:placing_organization_id)).order(:name).pluck(:name, :id)
      [
        Filter.new(key: "county", label: "County", options: counties.index_with(&:itself),
                   scope: ->(rows, value) { rows.where(county: value) }),
        Filter.new(key: "agency", label: "Agency", options: agencies.to_h,
                   scope: ->(rows, value) { rows.where(placing_organization_id: value) }),
        Filter.new(key: "payout", label: "Payout method", options: PAYOUT_METHODS,
                   scope: ->(rows, value) { rows.where(payout_method: value) })
      ]
    end

    def build_sorts
      [
        Sort.new(key: "name", label: "Household", order: "households.display_name"),
        Sort.new(key: "caregiver", label: "Caregiver", order: "users.last_name"),
        Sort.new(key: "agency", label: "Agency", order: "organizations.name"),
        Sort.new(key: "children", label: "Children", order: "children_count"),
        Sort.new(key: "asked", label: "Asked", order: "asked_cents"),
        Sort.new(key: "share", label: "Share", order: Figures.share_per_household(event)),
        Sort.new(key: "chosen", label: "Chosen", order: "chosen_cents"),
        Sort.new(key: "verification", label: "Verification", order: "households.verification_status"),
        Sort.new(key: "payout", label: "Payout", order: "households.payout_method")
      ]
    end
  end
end
