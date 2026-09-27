# frozen_string_literal: true

module Admin
  # What one donation went toward, in the words the ledger uses.
  class DonationChoice
    GENERAL = "Where it is needed most"
    RELEASED = "Chosen gifts, since returned to open"

    attr_reader :donation

    def initialize(donation)
      @donation = donation
    end

    def gifts
      donation.line_items
    end

    def parts
      [ gifts_part, general_part ].compact
    end

    def to_s
      parts.join(" + ")
    end

    def mixed?
      parts.size > 1
    end

    private

    def gifts_part
      return nil unless donation.gift_in_cents.positive?
      return RELEASED if gifts.empty?

      "#{gifts.size} #{'gift'.pluralize(gifts.size)} for #{aliases.to_sentence}"
    end

    def general_part
      GENERAL if donation.general_gift_in_cents.positive?
    end

    def aliases
      gifts.filter_map { |line| line.wishlist&.child&.display_name }.uniq
    end
  end
end
