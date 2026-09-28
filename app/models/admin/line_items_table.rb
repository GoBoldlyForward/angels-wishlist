# frozen_string_literal: true

module Admin
  # The Line items index: every gift on every list in the event.
  class LineItemsTable < Table
    PRICES = { "Under $40" => "0-40", "$40 to $80" => "40-80", "Over $80" => "80-" }.freeze
    SEARCHED = %w[line_items.name line_items.spec children.display_name households.display_name
                  donations.display_name users.first_name users.last_name].freeze

    # One word for where a line stands, funded first because a funded line keeps its open status.
    STATE = <<~SQL.squish.freeze
      (CASE WHEN line_items.status = 'withdrawn' THEN 'withdrawn'
            WHEN line_items.donation_id IS NOT NULL THEN 'funded'
            ELSE line_items.status END)
    SQL

    attr_reader :chapter, :event

    def initialize(chapter, event, params)
      @chapter = chapter
      @event = event
      super(line_items, params, tabs: build_tabs, filters: build_filters, sorts: build_sorts,
                                search: method(:matching), default_order: "line_items.created_at DESC, line_items.id DESC")
    end

    def rows
      super.preload(wishlist: { child: :household }, donation: :donor, catalog_item: :category)
    end

    # The index shows each gift's photograph, which an export has no use for.
    def rows_with_photos
      rows.preload(catalog_item: { photo_attachment: :blob })
    end

    def summary
      @summary ||= begin
        listed = line_items.listed
        { lines: listed.count, children: listed.distinct.count("wishlists.child_id"),
          funded: listed.funded.count, open: listed.shoppable.count,
          open_in_cents: listed.shoppable.sum(:price_in_cents), chosen_in_cents: listed.funded.sum(:price_in_cents) }
      end
    end

    def csv_columns
      {
        "Gift" => ->(row) { row.name },
        "Brand or size" => ->(row) { row.spec },
        "Link" => ->(row) { row.link_url },
        "Child" => ->(row) { row.wishlist.child.display_name },
        "Age" => ->(row) { row.wishlist.child.age },
        "Household" => ->(row) { row.wishlist.child.household.display_name },
        "Category" => ->(row) { row.catalog_item&.category&.name },
        "Price" => ->(row) { row.price_in_dollars },
        "Catalog price" => ->(row) { row.catalog_item&.price_in_dollars },
        "Status" => ->(row) { self.class.state_of(row) },
        "Funded by" => ->(row) { row.funder_display_name },
        "Donor" => ->(row) { row.donation&.donor&.full_name },
        "Funded on" => ->(row) { row.funded_at&.to_date },
        "Added" => ->(row) { row.created_at.to_date }
      }
    end

    def self.state_of(line_item)
      return "withdrawn" if line_item.withdrawn_status?

      line_item.funded? ? "funded" : line_item.status
    end

    private

    def line_items
      return LineItem.none unless event

      LineItem.joins(wishlist: { child: :household })
              .left_joins(catalog_item: :category, donation: :donor)
              .where(wishlists: { event_id: event.id }, households: { organization_id: chapter&.id })
    end

    def matching(rows, query)
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      rows.where(SEARCHED.map { |column| "#{column} ILIKE :pattern" }.join(" OR "), pattern: pattern)
    end

    def priced(rows, band)
      from, below = band.split("-")
      rows = rows.where(line_items: { price_in_cents: (from.to_i * 100).. })
      below ? rows.where(line_items: { price_in_cents: ...(below.to_i * 100) }) : rows
    end

    def build_tabs
      [
        Tab.new(key: "all", label: "All"),
        Tab.new(key: "open", label: "Open", tone: "warning", scope: ->(rows) { rows.shoppable }),
        Tab.new(key: "funded", label: "Funded", tone: "success", scope: ->(rows) { rows.listed.funded }),
        Tab.new(key: "specific", label: "Brand or size", scope: ->(rows) { rows.listed.specific }),
        Tab.new(key: "pooled", label: "In the pool", scope: ->(rows) { rows.shoppable.pooled }),
        Tab.new(key: "review", label: "Needs review", tone: "danger", scope: ->(rows) { rows.needs_review_status }),
        Tab.new(key: "withdrawn", label: "Withdrawn", scope: ->(rows) { rows.withdrawn_status })
      ]
    end

    def build_filters
      categories = Category.where(id: line_items.select("catalog_items.category_id")).ordered.pluck(:name, :id)
      named = Household.where(id: line_items.select("children.household_id")).order(:display_name).pluck(:display_name, :id)
      [
        Filter.new(key: "category", label: "Category", options: categories.to_h,
                   scope: ->(rows, value) { rows.where(catalog_items: { category_id: value }) }),
        Filter.new(key: "household", label: "Household", options: named.to_h,
                   scope: ->(rows, value) { rows.where(children: { household_id: value }) }),
        Filter.new(key: "age", label: "Age band", options: AgeBand::OPTIONS,
                   scope: ->(rows, value) { AgeBand.narrow(rows, value) }),
        Filter.new(key: "price", label: "Price", options: PRICES, scope: method(:priced))
      ]
    end

    def build_sorts
      [
        Sort.new(key: "gift", label: "Gift", order: "line_items.name"),
        Sort.new(key: "child", label: "Child", order: "children.display_name"),
        Sort.new(key: "category", label: "Category", order: "categories.name"),
        Sort.new(key: "price", label: "Price", order: "line_items.price_in_cents"),
        Sort.new(key: "status", label: "Status", order: STATE),
        Sort.new(key: "funder", label: "Funded by", order: "donations.display_name"),
        Sort.new(key: "added", label: "Added", order: "line_items.created_at")
      ]
    end
  end
end
