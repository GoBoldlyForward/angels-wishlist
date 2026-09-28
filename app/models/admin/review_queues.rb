# frozen_string_literal: true

module Admin
  # The Inbox page: the four queues, oldest first, with what each row shows
  # loaded up front.
  class ReviewQueues
    attr_reader :inbox

    delegate :count, to: :inbox

    def initialize(inbox)
      @inbox = inbox
    end

    def households
      @households ||= Figures.households(inbox.households, inbox.event)
                             .preload(:caregiver, :placing_organization).order(:created_at, :id).to_a
    end

    def wishlists
      @wishlists ||= Figures.lists(inbox.wishlists).order(:submitted_at, :id).to_a
    end

    def line_items
      @line_items ||= inbox.line_items.order(:created_at, :id).to_a
    end

    def donor_notes
      @donor_notes ||= inbox.donor_notes.preload(line_items: { wishlist: { child: :household } })
                            .order(:created_at, :id).to_a
    end

    def households_for(donation)
      donation.line_items.filter_map { |line| line.wishlist&.child&.household }.uniq
    end
  end
end
