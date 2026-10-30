# frozen_string_literal: true

module Admin
  # The chapter's year-end appeal, held as JSON on the organization: the words,
  # the figures, and the gift tiers donors see at checkout.
  class YearEndAppealForm < RecordForm
    PASSED_THROUGH = [].freeze
    STAT_FIELDS = %w[figure label].freeze
    TIER_FIELDS = %w[dollars title teaser body].freeze
    STAT_ROWS = 4
    TIER_ROWS = 7

    attr_reader :enabled, :stats, :tiers

    Storefront::YearEndAppeal::TEXT_FIELDS.each { |field| define_method(field) { @text[field] } }

    def stat_rows
      pad(stats, STAT_ROWS, STAT_FIELDS)
    end

    def tier_rows
      pad(tiers, TIER_ROWS, TIER_FIELDS)
    end

    private

    def assign
      current = Storefront::YearEndAppeal.new(chapter: record).to_h
      @enabled = @params.key?(:enabled) ? ActiveModel::Type::Boolean.new.cast(@params[:enabled]) : current["enabled"]
      @text = Storefront::YearEndAppeal::TEXT_FIELDS.index_with do |field|
        @params.key?(field) ? @params[field].to_s.strip : current[field]
      end
      @stats = rows(:stats, current["stats"], STAT_FIELDS)
      @tiers = rows(:tiers, current["tiers"], TIER_FIELDS).each { |tier| tier["dollars"] = whole_dollars(tier["dollars"]) }
      return if @params.empty?

      record.year_end_appeal = @text.merge("enabled" => @enabled, "stats" => @stats, "tiers" => @tiers)
    end

    # Rows arrive keyed by position. One left entirely blank is dropped.
    def rows(key, current, fields)
      return current.map { |row| row.slice(*fields).stringify_keys } unless @params.key?(key)

      given = @params[key]
      given = given.values if given.respond_to?(:values)
      Array(given).map { |row| fields.index_with { |field| row[field].to_s.strip } }
                  .reject { |row| row.values.all?(&:blank?) }
    end

    def pad(rows, count, fields)
      rows + Array.new([ count - rows.size, 0 ].max) { fields.index_with { "" } }
    end

    def whole_dollars(value)
      return value if value.is_a?(Integer)

      Integer(value.to_s.delete("$, "), exception: false) || value
    end

    def check
      errors.add(:base, "Give the appeal a headline") if enabled && headline.blank?
      errors.add(:base, "Each figure needs a number and a label") if stats.any? { |stat| stat.values.any?(&:blank?) }
      errors.add(:base, "Each tier needs a title") if tiers.any? { |tier| tier["title"].blank? }
      return if tiers.all? { |tier| tier["dollars"].is_a?(Integer) && tier["dollars"] >= 5 }

      errors.add(:base, "Tier amounts are whole dollars, $5 or more")
    end
  end
end
