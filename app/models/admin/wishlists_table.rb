# frozen_string_literal: true

module Admin
  # The Wishlists index: one row per child with a list in the event.
  class WishlistsTable < Table
    SEARCHED = [ "children.display_name", "children.legal_first_name", "households.display_name",
                 "households.county", "users.first_name", "users.last_name", "wishlists.caregiver_note",
                 "array_to_string(wishlists.interests, ' ')" ].freeze

    # No line a donor could still choose, and at least one line on the list.
    FULLY_CHOSEN = <<~SQL.squish.freeze
      EXISTS (SELECT 1 FROM line_items WHERE line_items.wishlist_id = wishlists.id
              AND line_items.deleted_at IS NULL AND line_items.status <> 'withdrawn')
      AND NOT EXISTS (SELECT 1 FROM line_items WHERE line_items.wishlist_id = wishlists.id
                      AND line_items.deleted_at IS NULL AND line_items.status = 'open'
                      AND line_items.donation_id IS NULL)
    SQL

    attr_reader :chapter, :event

    def initialize(chapter, event, params)
      @chapter = chapter
      @event = event
      super(wishlists, params, tabs: build_tabs, filters: build_filters, sorts: build_sorts,
                               search: method(:matching), default_order: "children.display_name ASC")
    end

    def rows
      Figures.lists(super).preload(child: { household: :caregiver })
    end

    def summary
      @summary ||= {
        lists: tab_counts["all"], live: tab_counts["live"], in_review: tab_counts["review"],
        fully_chosen: tab_counts["chosen"],
        asked_in_cents: lines.listed.sum(:price_in_cents), chosen_in_cents: lines.funded.sum(:price_in_cents)
      }
    end

    def share_for(wishlist)
      event ? event.share_for(wishlist) : 0
    end

    def csv_columns
      {
        "Child" => ->(row) { row.child.display_name },
        "Legal first name" => ->(row) { row.child.legal_first_name },
        "Age" => ->(row) { row.child.age },
        "Household" => ->(row) { row.child.household.display_name },
        "County" => ->(row) { row.child.household.county },
        "Caregiver" => ->(row) { row.child.household.caregiver&.full_name },
        "Gifts listed" => ->(row) { row.listed_count },
        "Gifts chosen" => ->(row) { row.chosen_count },
        "Asked" => ->(row) { row.asked_cents / 100.0 },
        "Chosen by donors" => ->(row) { row.chosen_cents / 100.0 },
        "Share" => ->(row) { share_for(row) / 100.0 },
        "Status" => ->(row) { row.status },
        "Returned because" => ->(row) { row.review_note },
        "Last gift" => ->(row) { row.last_gift_at&.to_date }
      }
    end

    private

    def wishlists
      return Wishlist.none unless event

      event.wishlists.joins(child: { household: :caregiver })
           .where(households: { organization_id: chapter&.id, archived_at: nil })
    end

    def lines
      LineItem.where(wishlist_id: wishlists.where.not(status: "withdrawn").select(:id))
    end

    def matching(rows, query)
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      rows.where(SEARCHED.map { |column| "#{column} ILIKE :pattern" }.join(" OR "), pattern: pattern)
    end

    def build_tabs
      [
        Tab.new(key: "all", label: "All"),
        Tab.new(key: "live", label: "Live", tone: "success", scope: ->(rows) { rows.live }),
        Tab.new(key: "review", label: "In review", tone: "warning", scope: ->(rows) { rows.in_review }),
        Tab.new(key: "returned", label: "Returned", tone: "danger",
                scope: ->(rows) { rows.draft.where.not(review_note: [ nil, "" ]) }),
        Tab.new(key: "chosen", label: "Fully chosen",
                scope: ->(rows) { rows.where.not(status: "withdrawn").where(FULLY_CHOSEN) }),
        Tab.new(key: "withdrawn", label: "Withdrawn", scope: ->(rows) { rows.withdrawn })
      ]
    end

    def build_filters
      named = Household.where(id: wishlists.select("children.household_id")).order(:display_name).pluck(:display_name, :id)
      counties = named.empty? ? [] : Household.where(id: named.map(&:last)).where.not(county: [ nil, "" ])
                                              .distinct.order(:county).pluck(:county)
      [
        Filter.new(key: "household", label: "Household", options: named.to_h,
                   scope: ->(rows, value) { rows.where(children: { household_id: value }) }),
        Filter.new(key: "county", label: "County", options: counties.index_with(&:itself),
                   scope: ->(rows, value) { rows.where(households: { county: value }) }),
        Filter.new(key: "age", label: "Age band", options: AgeBand::OPTIONS,
                   scope: ->(rows, value) { AgeBand.narrow(rows, value) })
      ]
    end

    def build_sorts
      [
        Sort.new(key: "child", label: "Child", order: "children.display_name"),
        Sort.new(key: "household", label: "Household", order: "households.display_name"),
        Sort.new(key: "gifts", label: "Gifts", order: "listed_count"),
        Sort.new(key: "asked", label: "Asked", order: "asked_cents"),
        Sort.new(key: "chosen", label: "Chosen by donors", order: "chosen_cents"),
        Sort.new(key: "share", label: "Share", order: Figures.share_per_list(event)),
        Sort.new(key: "status", label: "Status", order: "wishlists.status"),
        Sort.new(key: "last_gift", label: "Last gift", order: "last_gift_at")
      ]
    end
  end
end
