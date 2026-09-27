# frozen_string_literal: true

module Admin
  # Everything waiting on a staff decision. A query across the records that
  # own the text, not a table of its own.
  class Inbox
    attr_reader :event

    def initialize(event)
      @event = event
    end

    def households
      return Household.none unless event

      Household.active.verification_pending.where(id: event.enrollments.submitted.select(:household_id))
    end

    def wishlists
      return Wishlist.none unless event

      event.wishlists.needing_review.includes(child: :household)
    end

    def line_items
      return LineItem.none unless event

      LineItem.needs_review_status.where(wishlist_id: event.wishlists.where.not(status: %w[draft withdrawn]).select(:id))
              .includes(:catalog_item, wishlist: { child: :household })
    end

    def donor_notes
      return Donation.none unless event

      event.donations.succeeded.with_unapproved_note.includes(:donor)
    end

    def count
      households.count + wishlists.count + line_items.count + donor_notes.count
    end
  end
end
