# frozen_string_literal: true

module Storefront
  # Every list a donor may see for one event, loaded once and grouped in Ruby.
  # Browsing by gift and browsing by child are two views of these rows.
  class Catalog
    UNDER_IN_CENTS = 4_000

    def initialize(event:, cart_ids: [])
      @event = event
      @cart_ids = cart_ids
    end

    def children
      @children ||= wishlists.map do |wishlist|
        ChildCard.new(wishlist, lines: lines_by_wishlist.fetch(wishlist.id, []), cart_ids: @cart_ids)
      end
    end

    def gifts
      @gifts ||= children.flat_map(&:gifts).sort_by(&:waiting_order)
    end

    def products(filters = nil)
      Product.group(filters ? gifts.select { |gift| filters.matches?(gift) } : gifts)
    end

    def open_gifts(filters = nil)
      gifts.reject(&:funded?).select { |gift| filters.nil? || filters.matches?(gift) }
    end

    def categories
      @categories ||= Category.where(organization_id: @event&.organization_id).ordered.to_a
    end

    def category_gifts(category)
      gifts.select { |gift| gift.category&.id == category.id }
    end

    def custom_products
      Product.group(gifts.select { |gift| gift.catalog_item.nil? })
    end

    def child(key)
      children.find { |card| card.key == key }
    end

    def product(key)
      products.find { |product| product.key == key }
    end

    def almost_finished
      children.select { |card| card.left.one? }.map { |card| card.left.first }
    end

    def untouched
      children.select { |card| card.untouched? && card.left.any? }
    end

    def under_forty
      Product.group(open_gifts.select { |gift| gift.price_in_cents <= UNDER_IN_CENTS })
    end

    def teenagers
      children.select { |card| card.teen? && card.left.any? }
    end

    def new_this_week
      children.select(&:new_this_week?).reverse
    end

    def household_count(gifts)
      gifts.map { |gift| households_by_child_key[gift.child.key] }.uniq.size
    end

    def empty?
      children.empty?
    end

    def self.shoppable_lines(event)
      return LineItem.none if event.nil?

      LineItem.visible_to_donors.unfunded
              .where(wishlist_id: Wishlist.visible_to_donors.where(event_id: event.id).select(:id))
    end

    private

    def wishlists
      @wishlists ||= if @event
        Wishlist.visible_to_donors.where(event_id: @event.id)
                .preload(child: :household).order(:approved_at, :id).to_a
      else
        []
      end
    end

    def lines_by_wishlist
      @lines_by_wishlist ||= LineItem.visible_to_donors.where(wishlist_id: wishlists.map(&:id)).oldest_first
                                     .preload(:donation, catalog_item: [ :category, { photo_attachment: :blob } ])
                                     .group_by(&:wishlist_id)
    end

    def households_by_child_key
      @households_by_child_key ||= wishlists.to_h { |wishlist| [ wishlist.slug, wishlist.child.household_id ] }
    end
  end
end
