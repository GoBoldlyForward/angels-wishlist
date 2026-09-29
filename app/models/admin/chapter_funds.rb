# frozen_string_literal: true

module Admin
  # The chapter's Stripe balance, what of it caregivers are still owed, and what may go to the bank.
  class ChapterFunds
    Held = Data.define(:event, :owed_in_cents, :paid_in_cents) do
      def held_in_cents
        [ owed_in_cents - paid_in_cents, 0 ].max
      end
    end

    SENT = %w[sent delivered].freeze

    attr_reader :chapter

    def initialize(chapter)
      @chapter = chapter
    end

    def balance_in_cents
      @balance_in_cents ||= PaymentGateway.chapter_balance_in_cents(chapter)
    end

    def events
      @events ||= chapter.events.newest_first.map { |event| held_for(event) }.select { |row| row.held_in_cents.positive? }
    end

    def held_in_cents
      events.sum(&:held_in_cents)
    end

    def releasable_in_cents
      return 0 if balance_in_cents.nil?

      [ balance_in_cents - held_in_cents, 0 ].max
    end

    def release(cents)
      cents = cents.to_i
      return "Choose an amount above zero." unless cents.positive?
      return "Only #{Dollars.from_cents(releasable_in_cents)} is free to send. The rest is owed to caregivers." if cents > releasable_in_cents

      PaymentGateway.release_to_bank(chapter, cents)
      nil
    end

    private

    # A household paid by gift card is paid from the chapter's bank, so its share is not held here.
    def held_for(event)
      by_card = event.counted_wishlists.where(households: { payout_method: "gift_card" }).pluck(:id)
      owed = event.shares.sum { |wishlist_id, cents| by_card.include?(wishlist_id) ? 0 : cents }
      stripe = event.payouts.via_stripe
      paid = stripe.where(status: SENT).sum(:amount_in_cents) +
             stripe.where.not(status: SENT).sum("COALESCE(debited_in_cents, 0)")
      Held.new(event:, owed_in_cents: owed, paid_in_cents: paid)
    end
  end
end
