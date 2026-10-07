# frozen_string_literal: true

module Admin
  # The figures and the worklist on the staff overview, for one event.
  class Overview
    CATEGORIES_SHOWN = 7
    HOUSEHOLDS_SHOWN = 5
    LISTS_SHOWN = 6
    NOT_IN_CATALOG = "Not in the catalog"

    attr_reader :chapter, :event

    delegate :raised_in_cents, :goal_in_cents, :percent_funded, :days_remaining, to: :event

    def initialize(chapter, event)
      @chapter = chapter
      @event = event
    end

    def inbox
      @inbox ||= Inbox.new(event)
    end

    def lines_listed
      lines.listed.count
    end

    def lines_chosen
      lines.listed.funded.count
    end

    def lines_open
      lines.shoppable.count
    end

    def lists_count
      lists.count
    end

    def lists_live
      lists.live.count
    end

    def lists_in_review
      lists.in_review.count
    end

    def households_count
      households.count
    end

    def households_not_verified
      households.where.not(verification_status: "verified").count
    end

    # Households with a list in front of staff or donors that could not be paid today.
    def unpayable_households
      @unpayable_households ||= households.where(id: lists.where(status: %w[in_review live closed])
                                                          .select("children.household_id"))
                                          .order(:display_name).reject(&:payable?)
    end

    def nothing_chosen_count
      @nothing_chosen_count ||= untouched_lists.count
    end

    def lists_with_nothing_chosen
      @lists_with_nothing_chosen ||= Figures.lists(untouched_lists).preload(child: :household)
                                            .order(:approved_at, :id).limit(LISTS_SHOWN)
    end

    def disputed_donations
      @disputed_donations ||= event.donations.disputed.count
    end

    def pending_donations
      @pending_donations ||= event.donations.pending.count
    end

    def needs_attention?
      unpayable_households.any? || inbox.count.positive? || nothing_chosen_count.positive? ||
        (disputed_donations + pending_donations).positive?
    end

    # [[category name, open lines], ...], the most open first.
    def open_lines_by_category
      @open_lines_by_category ||= lines.shoppable.left_joins(catalog_item: :category).group("categories.name").count
                                       .transform_keys { |name| name || NOT_IN_CATALOG }
                                       .sort_by { |name, count| [ -count, name ] }.first(CATEGORIES_SHOWN)
    end

    private

    def households
      Household.active.where(organization: chapter)
    end

    def lists
      event.wishlists.joins(child: :household).where(households: { organization_id: chapter.id, archived_at: nil })
    end

    def untouched_lists
      lists.live.where.not(id: lines.funded.select(:wishlist_id))
    end

    def lines
      LineItem.where(wishlist_id: lists.where.not(status: "withdrawn").select(:id))
    end
  end
end
