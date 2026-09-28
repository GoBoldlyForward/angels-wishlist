# frozen_string_literal: true

module Admin
  # The audit trail: every recorded change, newest first.
  class VersionsTable < Table
    SEARCHED = %w[versions.item_type versions.event versions.object_changes::text].freeze

    def initialize(params)
      super(Version.all, params, tabs: build_tabs, filters: build_filters, sorts: build_sorts,
                                 search: method(:matching), default_order: "versions.created_at DESC, versions.id DESC")
    end

    def rows
      super.preload(:actor, :item)
    end

    def csv_columns
      {
        "When" => ->(row) { row.created_at&.iso8601 },
        "Who" => ->(row) { row.actor&.full_name || row.whodunnit },
        "What happened" => ->(row) { row.event },
        "Record" => ->(row) { "#{row.item_type} #{row.item_id}" },
        "What changed" => lambda do |row|
          row.changeset.map { |field, (before, after)| "#{field}: #{before.inspect} -> #{after.inspect}" }.join("; ")
        end
      }
    end

    private

    def matching(rows, query)
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      rows.where(SEARCHED.map { |column| "#{column} ILIKE :pattern" }.join(" OR "), pattern: pattern)
    end

    def build_tabs
      [
        Tab.new(key: "all", label: "All"),
        Tab.new(key: "create", label: "Created", scope: ->(rows) { rows.where(event: "create") }),
        Tab.new(key: "update", label: "Changed", scope: ->(rows) { rows.where(event: "update") }),
        Tab.new(key: "destroy", label: "Removed", scope: ->(rows) { rows.where(event: "destroy") })
      ]
    end

    def build_filters
      types = Version.distinct.order(:item_type).pluck(:item_type)
      actors = User.with_deleted.where(id: Version.where.not(whodunnit: nil).distinct.pluck(:whodunnit))
                   .sort_by { |user| user.full_name.downcase }
      [
        Filter.new(key: "type", label: "Record", options: types.to_h { |type| [ type.underscore.humanize, type ] },
                   scope: ->(rows, value) { rows.where(item_type: value) }),
        Filter.new(key: "actor", label: "Who", options: actors.to_h { |user| [ user.full_name, user.id ] },
                   scope: ->(rows, value) { rows.where(whodunnit: value) })
      ]
    end

    def build_sorts
      [
        Sort.new(key: "when", label: "When", order: "versions.created_at"),
        Sort.new(key: "record", label: "Record", order: "versions.item_type")
      ]
    end
  end
end
