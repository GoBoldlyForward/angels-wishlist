# frozen_string_literal: true

module Admin
  # One giver's season: what they gave to one event and what they chose.
  class Donor
    attr_reader :user, :event

    delegate :full_name, :email, :to_param, to: :user

    def initialize(user, event)
      @user = user
      @event = event
    end

    def type
      DonorType.of(user)
    end

    def donations
      @donations ||= event.donations.where(donor: user).recent
                          .includes(line_items: { wishlist: :child }).to_a
    end

    def succeeded
      donations.select(&:succeeded?)
    end

    def latest_succeeded
      succeeded.first
    end

    def given_in_cents
      succeeded.sum(&:given_in_cents)
    end

    def general_in_cents
      succeeded.sum(&:general_gift_in_cents)
    end

    def fees_in_cents
      succeeded.sum(&:fee_in_cents)
    end

    def chosen_gifts
      succeeded.flat_map(&:line_items)
    end

    def shown_as
      return "Anonymous" if anonymous?

      donations.first&.display_name.presence || full_name
    end

    def anonymous?
      donations.any?(&:anonymous?)
    end
  end
end
