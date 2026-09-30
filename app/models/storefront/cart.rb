# frozen_string_literal: true

module Storefront
  # A visitor's cart, held in the session as line item ids and general gift
  # amounts in cents. Only lines a donor may fund right now ever get in.
  class Cart
    SESSION_KEY = "cart"
    LARGEST_GENERAL_GIFT_IN_CENTS = 10_000_000
    LARGEST_QUANTITY = 200

    attr_reader :dropped_count

    def initialize(session, event:)
      @session = session
      @event = event
      @dropped_count = 0
    end

    def line_item_ids
      Array(store["line_item_ids"]).map(&:to_i)
    end

    def general_gifts
      Array(store["general_gifts"]).map(&:to_i)
    end

    # The lines still open, in the order they were added. One that closed since
    # it was added leaves the cart here and is counted in dropped_count.
    def lines
      @lines ||= begin
        open = shoppable.where(id: line_item_ids)
                        .preload(catalog_item: [ :category, { photo_attachment: :blob } ],
                                 wishlist: { child: :household })
                        .index_by(&:id)
        kept = line_item_ids.select { |id| open.key?(id) }
        @dropped_count += line_item_ids.size - kept.size
        write("line_item_ids" => kept) if kept != line_item_ids
        open.values_at(*kept)
      end
    end

    def gifts
      lines.map { |line| Gift.new(line, child: ChildCard.new(line.wishlist), in_cart: true) }
    end

    def gifts_by_child
      gifts.group_by { |gift| gift.child.key }.values
    end

    def gift_in_cents
      lines.sum(&:price_in_cents)
    end

    def general_gift_in_cents
      general_gifts.sum
    end

    def total_in_cents
      gift_in_cents + general_gift_in_cents
    end

    def fee_in_cents
      Donation.fee_for(total_in_cents, platform_fee_basis_points: @event&.organization&.platform_fee_basis_points.to_i)
    end

    def count
      lines.size + general_gifts.size
    end

    def add_gift(key)
      line = Gift.find_line(key)
      line ? add(shoppable.where(id: line.id)) : 0
    end

    # The oldest open pooled lines for the product, skipping what is already here.
    def add_pooled(catalog_item, quantity)
      add(shoppable.pooled.where(catalog_item_id: catalog_item.id), limit: quantity)
    end

    def add_from_category(category, quantity = nil)
      add(shoppable.where(catalog_item_id: category.catalog_items.select(:id)), limit: quantity)
    end

    def add_list(child_key)
      add(shoppable.where(wishlist: Wishlist.where(slug: child_key.to_s)))
    end

    def add_general_gift(cents)
      return false unless cents.to_i.between?(Donation::MINIMUM_GENERAL_GIFT_IN_CENTS, LARGEST_GENERAL_GIFT_IN_CENTS)

      write("general_gifts" => general_gifts + [ cents.to_i ])
      true
    end

    def add_general_gift_in_dollars(dollars)
      amount = BigDecimal(dollars.to_s.delete("$, "), exception: false)
      amount&.finite? ? add_general_gift((amount * 100).round) : false
    end

    def remove_gift(key)
      line = Gift.find_line(key)
      remove_lines([ line.id ]) if line
    end

    def remove_product(product)
      remove_lines(product.carted.filter_map { |gift| Gift.find_line(gift.key)&.id })
    end

    def remove_general_gift(index)
      amounts = general_gifts
      return unless index.to_s.match?(/\A\d+\z/) && amounts.delete_at(index.to_i)

      write("general_gifts" => amounts)
    end

    def clear
      @session.delete(SESSION_KEY)
      @lines = nil
    end

    def empty?
      count.zero?
    end

    def holds_gifts?
      lines.any?
    end

    private

    def store
      @session[SESSION_KEY] || {}
    end

    def write(changes)
      @session[SESSION_KEY] = { "line_item_ids" => line_item_ids, "general_gifts" => general_gifts }.merge(changes)
    end

    def shoppable
      Catalog.shoppable_lines(@event)
    end

    def add(open_lines, limit: nil)
      limit = limit.to_i.clamp(0, LARGEST_QUANTITY) unless limit.nil?
      ids = open_lines.where.not(id: line_item_ids).oldest_first.limit(limit).pluck(:id)
      write("line_item_ids" => line_item_ids + ids)
      @lines = nil
      ids.size
    end

    def remove_lines(ids)
      write("line_item_ids" => line_item_ids - ids)
      @lines = nil
    end
  end
end
