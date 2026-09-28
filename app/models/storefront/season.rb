# frozen_string_literal: true

module Storefront
  # The one goal at the top of the home page.
  class Season
    SMALLEST_BAR = 2

    def initialize(event, catalog)
      @event = event
      @catalog = catalog
    end

    def raised_in_cents
      @raised_in_cents ||= @event.raised_in_cents
    end

    def goal_in_cents
      @goal_in_cents ||= @event.goal_in_cents
    end

    def percent
      return 0 if goal_in_cents.zero?

      [ (raised_in_cents * 100.0 / goal_in_cents).round, 100 ].min
    end

    def bar_width
      percent.clamp(SMALLEST_BAR, 100)
    end

    def closes_on
      @event.closes_at&.to_date
    end

    def days_remaining
      @event.days_remaining
    end

    def gifts_chosen
      @catalog.gifts.count(&:funded?)
    end

    def children_with_lists
      @catalog.children.size
    end

    def lists_finished
      @catalog.children.count(&:complete?)
    end

    def open?
      @event.open?
    end
  end
end
