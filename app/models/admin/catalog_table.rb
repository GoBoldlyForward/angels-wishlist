# frozen_string_literal: true

module Admin
  # The catalog a caregiver's typed gift is matched against.
  class CatalogTable < Table
    AGES = "COALESCE(catalog_items.min_age, 0)"

    CSV_COLUMNS = {
      "Name" => ->(item) { item.name },
      "Category" => ->(item) { item.category.name },
      "Price" => ->(item) { Dollars.from_cents(item.price_in_cents) },
      "Minimum age" => ->(item) { item.min_age },
      "Maximum age" => ->(item) { item.max_age },
      "Active" => ->(item) { item.active ? "yes" : "no" },
      "Photo attribution" => ->(item) { item.photo_attribution }
    }.freeze

    def initialize(params)
      super(items, params, tabs: catalog_tabs, filters: catalog_filters, sorts: catalog_sorts,
            search: method(:matching), default_order: Arel.sql("categories.position, catalog_items.name"))
    end

    def item_count
      tab_counts["all"]
    end

    def active_count
      tab_counts["active"]
    end

    def without_photo_count
      tab_counts["no_photo"]
    end

    def category_count
      Category.count
    end

    def price_range
      CatalogItem.available.pick(Arel.sql("MIN(price_in_cents)"), Arel.sql("MAX(price_in_cents)"))
    end

    private

    def items
      CatalogItem.joins(:category).preload(:category).with_attached_photo
    end

    def catalog_tabs
      [
        Tab.new(key: "all", label: "All"),
        Tab.new(key: "active", label: "Active", scope: ->(rows) { rows.where(active: true) }),
        Tab.new(key: "inactive", label: "Inactive", scope: ->(rows) { rows.where(active: false) }),
        Tab.new(key: "no_photo", label: "No photo", scope: method(:without_photo))
      ]
    end

    def catalog_filters
      [
        Filter.new(key: "category", label: "Category",
                   options: Category.ordered.pluck(:name, :id).to_h.transform_values(&:to_s),
                   scope: ->(rows, value) { rows.where(category_id: value) }),
        Filter.new(key: "price", label: "Price",
                   options: { "Under $25" => "0-2499", "$25 to $50" => "2500-4999", "$50 to $100" => "5000-9999",
                              "$100 and up" => "10000-" },
                   scope: ->(rows, value) { within(rows, *value.split("-", 2)) })
      ]
    end

    def catalog_sorts
      [
        Sort.new(key: "name", label: "Name", order: "catalog_items.name"),
        Sort.new(key: "category", label: "Category", order: "categories.position"),
        Sort.new(key: "price", label: "Price", order: "catalog_items.price_in_cents"),
        Sort.new(key: "ages", label: "Ages", order: AGES)
      ]
    end

    def without_photo(rows)
      uploaded = ActiveStorage::Attachment.where(record_type: "CatalogItem", name: "photo").select(:record_id)
      rows.where(stock_photo: [ nil, "" ]).where.not(id: uploaded)
    end

    def within(rows, low, high)
      rows = rows.where("catalog_items.price_in_cents >= ?", low.to_i)
      high.present? ? rows.where("catalog_items.price_in_cents <= ?", high.to_i) : rows
    end

    def matching(rows, query)
      rows.where("catalog_items.name ILIKE ?", "%#{CatalogItem.sanitize_sql_like(query)}%")
    end
  end
end
