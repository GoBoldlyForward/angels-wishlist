# frozen_string_literal: true

module Storefront
  # Everything a donor may know about a child. Values are copied off the records,
  # so a column added later cannot reach a public page through this.
  class ChildCard
    NEW_FOR = 7.days
    TEEN_AGE = 13

    attr_reader :key, :alias_name, :age, :gender, :county, :interests, :note, :gifts

    def initialize(wishlist, lines: [], cart_ids: [])
      child = wishlist.child
      @key = wishlist.slug
      @alias_name = child.display_name
      @age = child.age
      @gender = child.gender
      @county = child.household.county
      @interests = wishlist.interests.to_a
      @note = wishlist.caregiver_note
      @approved_at = wishlist.approved_at
      @gifts = lines.map { |line| Gift.new(line, child: self, in_cart: cart_ids.include?(line.id)) }
    end

    def to_s
      [ alias_name, age ].compact.join(", ")
    end

    def gender_label
      { "girl" => "Girl", "boy" => "Boy" }[gender]
    end

    def meta
      [ gender_label, county ].compact_blank.join(" · ")
    end

    def asked_in_cents
      gifts.sum(&:price_in_cents)
    end

    def chosen_in_cents
      gifts.select(&:funded?).sum(&:price_in_cents)
    end

    def percent_chosen
      return 0 if asked_in_cents.zero?

      (chosen_in_cents * 100.0 / asked_in_cents).round
    end

    # What this visitor could still add: open and not already in their cart.
    def left
      gifts.select(&:available?)
    end

    def left_in_cents
      left.sum(&:price_in_cents)
    end

    def in_cart
      gifts.select(&:in_cart?)
    end

    def complete?
      gifts.any? && gifts.all?(&:funded?)
    end

    def untouched?
      gifts.none?(&:funded?)
    end

    def teen?
      age.to_i >= TEEN_AGE
    end

    def new_this_week?
      @approved_at.present? && @approved_at >= NEW_FOR.ago
    end
  end
end
