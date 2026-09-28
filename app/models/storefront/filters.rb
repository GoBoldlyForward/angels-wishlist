# frozen_string_literal: true

module Storefront
  # The filter pills: who a gift is for, their age band, and its price band.
  class Filters
    Group = Data.define(:key, :icon, :any_label, :options)

    GROUPS = [
      Group.new(key: :gender, icon: "fa-child-reaching", any_label: "Anyone",
                options: { "girl" => "A girl", "boy" => "A boy" }),
      Group.new(key: :age, icon: "fa-cake-candles", any_label: "Any age",
                options: { "0-5" => "0 to 5", "6-9" => "6 to 9", "10-12" => "10 to 12", "13-18" => "13 to 18" }),
      Group.new(key: :price, icon: "fa-tag", any_label: "Any price",
                options: { "u25" => "Under $25", "25-50" => "$25 to $50", "50-100" => "$50 to $100",
                           "100+" => "$100 and up" })
    ].freeze

    AGE_BANDS = { "0-5" => 0..5, "6-9" => 6..9, "10-12" => 10..12, "13-18" => 13.. }.freeze
    PRICE_BANDS = { "u25" => ..2_500, "25-50" => 2_500..5_000, "50-100" => 5_000..10_000,
                    "100+" => 10_000.. }.freeze

    def initialize(params = {})
      @chosen = GROUPS.to_h do |group|
        value = params[group.key].to_s
        [ group.key, group.options.key?(value) ? value : nil ]
      end
    end

    def groups(only: GROUPS.map(&:key))
      GROUPS.select { |group| only.include?(group.key) }
    end

    def value(key)
      @chosen[key]
    end

    def label(group)
      group.options.fetch(value(group.key), group.any_label)
    end

    def to_h
      @chosen.compact
    end

    # The query a pill's option links to: this set of filters with one changed.
    def with(key, value)
      @chosen.merge(key => value).compact
    end

    def matches?(gift)
      matches_child?(gift.child) && (price_band.nil? || price_band.cover?(gift.price_in_cents))
    end

    def matches_child?(child)
      (value(:gender).nil? || child.gender == value(:gender)) &&
        (age_band.nil? || (child.age.present? && age_band.cover?(child.age)))
    end

    def any?(only: GROUPS.map(&:key))
      only.any? { |key| value(key) }
    end

    private

    def age_band
      AGE_BANDS[value(:age)]
    end

    def price_band
      PRICE_BANDS[value(:price)]
    end
  end
end
