# frozen_string_literal: true

module Storefront
  # One category's landing page: what is still open in it and what funding it would take.
  class CategoryPage
    STARTING_QUANTITY = 2

    attr_reader :category

    def initialize(category, catalog:, filters:)
      @category = category
      @catalog = catalog
      @filters = filters
    end

    def headline
      category.headline.presence || category.name
    end

    # Oldest first, which is the order funding takes them in.
    def available
      @available ||= gifts.select(&:available?)
    end

    def prices
      available.map(&:price_in_cents)
    end

    def children_count
      available.map { |gift| gift.child.key }.uniq.size
    end

    def household_count
      @catalog.household_count(available)
    end

    def starting_quantity
      [ STARTING_QUANTITY, available.size ].min
    end

    def starting_in_cents
      prices.first(starting_quantity).sum
    end

    def whole_in_cents
      prices.sum
    end

    def products
      Product.group(gifts.select { |gift| @filters.matches?(gift) })
    end

    def other_categories
      (@catalog.categories - [ category ]).map do |other|
        [ other, @catalog.category_gifts(other).count { |gift| !gift.funded? } ]
      end
    end

    private

    def gifts
      @gifts ||= @catalog.category_gifts(category)
    end
  end
end
