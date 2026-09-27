# frozen_string_literal: true

module Storefront
  # A donation as its donor sees it on the confirmation page.
  class Receipt
    # chosen: gifts this donation funded, or will once the payment settles.
    # pooled: gifts somebody else funded first, whose amount stayed in the pool.
    attr_reader :key, :status, :given_in_cents, :fee_in_cents, :charged_in_cents, :note, :display_name,
                :chosen, :pooled

    def initialize(donation)
      @key = donation.uuid
      @status = donation.status
      @given_in_cents = donation.given_in_cents
      @fee_in_cents = donation.fee_in_cents
      @charged_in_cents = donation.charged_in_cents
      @general_gift_in_cents = donation.general_gift_in_cents
      @note = donation.note_to_family.presence
      @display_name = Gift.public_name(donation)
      @chosen, @pooled = split(donation)
    end

    def chosen_by_child
      chosen.group_by { |gift| gift.child.key }.values
    end

    def general_gift_in_cents
      [ @general_gift_in_cents - pooled.sum(&:price_in_cents), 0 ].max
    end

    def children
      chosen.map(&:child).uniq(&:key)
    end

    def pending?
      status == "pending"
    end

    def succeeded?
      status == "succeeded"
    end

    def failed?
      status == "failed"
    end

    def returned?
      %w[refunded disputed].include?(status)
    end

    private

    def split(donation)
      lines = donation.chosen_line_items.oldest_first
                      .preload(:donation, catalog_item: [ :category, { photo_attachment: :blob } ],
                               wishlist: { child: :household })
                      .select { |line| line.wishlist&.child&.household }
      mine, others = lines.partition { |line| !donation.succeeded? || line.donation_id == donation.id }
      [ mine, others ].map { |rows| rows.map { |line| Gift.new(line, child: ChildCard.new(line.wishlist)) } }
    end
  end
end
