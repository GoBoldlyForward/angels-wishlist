# frozen_string_literal: true

require "csv"

module Admin
  # One index page: a relation narrowed by a tab, a search, and filters, then
  # sorted. Every index shares it, so none of that is written twice.
  class Table
    Tab = Data.define(:key, :label, :scope, :tone) do
      def initialize(key:, label:, scope: ->(rows) { rows }, tone: nil)
        super
      end
    end

    # options maps what staff read to the value in the URL: { "Verified" => "verified" }
    Filter = Data.define(:key, :label, :options, :scope)

    # order is SQL written by us, never by the request: "households.display_name"
    Sort = Data.define(:key, :label, :order)

    DIRECTIONS = %w[asc desc].freeze

    attr_reader :tabs, :filters, :sorts

    def initialize(relation, params, tabs:, filters: [], sorts: [], search: nil, default_order: nil)
      @relation = relation
      @params = params
      @tabs = tabs
      @filters = filters
      @sorts = sorts
      @search = search
      @default_order = default_order
    end

    def tab
      tabs.find { |tab| tab.key == @params[:tab].to_s } || tabs.first
    end

    def tab_counts
      @tab_counts ||= tabs.to_h { |tab| [ tab.key, tab.scope.call(@relation).unscope(:order).distinct.count ] }
    end

    def query
      @params[:q].to_s.strip
    end

    def filter_value(filter)
      value = @params.dig(:f, filter.key).to_s
      filter.options.values.map(&:to_s).include?(value) ? value.presence : nil
    end

    def active_filters
      filters.select { |filter| filter_value(filter) }
    end

    def sort
      sorts.find { |sort| sort.key == @params[:sort].to_s }
    end

    def direction
      DIRECTIONS.include?(@params[:dir].to_s) ? @params[:dir].to_s : "asc"
    end

    def rows
      rows = tab.scope.call(@relation)
      rows = @search.call(rows, query) if @search && query.present?
      rows = active_filters.reduce(rows) { |narrowed, filter| filter.scope.call(narrowed, filter_value(filter)) }
      order(rows)
    end

    # What a link needs to keep the current view while changing one thing.
    def link_params(changes = {})
      { tab: tab.key, q: query.presence, f: active_filters.to_h { |f| [ f.key, filter_value(f) ] }.presence,
        sort: sort&.key, dir: sort && direction }.merge(changes).compact
    end

    # columns maps a header to what goes under it: { "Household" => ->(row) { row.display_name } }
    def to_csv(columns)
      CSV.generate do |csv|
        csv << columns.keys
        rows.find_each { |row| csv << columns.values.map { |value| value.call(row) } }
      end
    end

    private

    def order(rows)
      return rows.reorder(Arel.sql("#{sort.order} #{direction} NULLS LAST")) if sort
      return rows.reorder(@default_order) if @default_order

      rows
    end
  end
end
