# frozen_string_literal: true

module Storefront
  # One tile: every child's request for the same catalog item, counted together.
  class Product
    attr_reader :key, :gifts

    def initialize(key, gifts)
      @key = key
      @gifts = gifts
    end

    def name
      gifts.first.product_name
    end

    def catalog_item
      gifts.first.catalog_item
    end

    def category
      gifts.first.category
    end

    def open
      gifts.reject(&:funded?)
    end

    def left
      gifts.select(&:available?)
    end

    def carted
      gifts.select(&:in_cart?)
    end

    def funded
      gifts.select(&:funded?)
    end

    def pooled_left
      custom? ? [] : left.select(&:pooled?)
    end

    def specific_left
      custom? ? left : left.reject(&:pooled?)
    end

    def chosen_by
      funded.filter_map(&:chosen_by).uniq
    end

    # A funded tile keeps showing what it cost rather than nothing.
    def prices
      (open.presence || gifts).map(&:price_in_cents).uniq
    end

    def lowest_price_in_cents
      prices.min.to_i
    end

    def custom?
      catalog_item.nil?
    end

    def done?
      left.empty?
    end

    def varied_prices?
      prices.many?
    end

    def self.group(gifts)
      gifts.group_by(&:product_key).map { |key, rows| new(key, rows) }
    end

    def self.most_needed_first(products)
      products.sort_by { |product| [ -product.left.size, product.name.downcase ] }
    end
  end
end
