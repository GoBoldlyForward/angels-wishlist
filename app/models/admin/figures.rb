# frozen_string_literal: true

module Admin
  # The sums an index shows beside each row, as SQL, so a page reads them in
  # one query and can sort by them.
  module Figures
    SUM = "COALESCE(SUM(line_items.price_in_cents), 0)"
    COUNT = "COUNT(*)"

    module_function

    # Adds listed_count, chosen_count, asked_cents, chosen_cents, and last_gift_at to wishlists.
    def lists(wishlists)
      wishlists.select(
        "wishlists.*",
        "#{per_list(LineItem.listed, COUNT)} AS listed_count",
        "#{per_list(LineItem.funded, COUNT)} AS chosen_count",
        "#{per_list(LineItem.listed, SUM)} AS asked_cents",
        "#{per_list(LineItem.funded, SUM)} AS chosen_cents",
        "#{per_list(LineItem.funded.joins(:donation), 'MAX(donations.created_at)')} AS last_gift_at"
      )
    end

    # Adds children_count, asked_cents, and chosen_cents to households, for one event.
    def households(households, event)
      households.select(
        "households.*",
        "(#{Child.active.where('children.household_id = households.id').select(COUNT).to_sql}) AS children_count",
        "#{per_household(LineItem.listed, event, SUM)} AS asked_cents",
        "#{per_household(LineItem.funded, event, SUM)} AS chosen_cents"
      )
    end

    def per_list(lines, figure)
      "(#{lines.where('line_items.wishlist_id = wishlists.id').select(figure).to_sql})"
    end

    # A withdrawn list is no longer asking, so its lines are left out.
    def per_household(lines, event, figure)
      lines = lines.joins(wishlist: :child).where(wishlists: { event_id: event&.id })
                   .where.not(wishlists: { status: "withdrawn" })
                   .where("children.household_id = households.id")
      "(#{lines.select(figure).to_sql})"
    end

    # What the pool is spread across: a list outside the count has no share.
    def share_per_list(event)
      return "0" unless event

      "(CASE WHEN wishlists.id IN (#{event.counted_wishlists.select(:id).to_sql}) " \
        "THEN #{per_list(LineItem.listed, SUM)} ELSE 0 END)"
    end

    def share_per_household(event)
      return "0" unless event

      per_household(LineItem.listed.where(wishlist_id: event.counted_wishlists.select(:id)), event, SUM)
    end
  end
end
