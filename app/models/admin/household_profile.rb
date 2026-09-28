# frozen_string_literal: true

module Admin
  # One household as its staff page shows it, for one event.
  class HouseholdProfile
    attr_reader :household, :event

    def initialize(household, event)
      @household = household
      @event = event
    end

    def children
      @children ||= household.children.active.order(:birthdate, :id).to_a
    end

    def wishlist_for(child)
      wishlists[child.id]
    end

    def lists_in_review
      wishlists.values.select(&:in_review?)
    end

    def asked_in_cents
      wishlists.values.reject(&:withdrawn?).sum(&:asked_cents)
    end

    def chosen_in_cents
      wishlists.values.reject(&:withdrawn?).sum(&:chosen_cents)
    end

    def share_in_cents
      event ? household.share_in_cents(event) : 0
    end

    def share_for(wishlist)
      event.share_for(wishlist)
    end

    def payout_status
      event ? household.payout_status(event) : :blocked
    end

    def enrollment
      return @enrollment if defined?(@enrollment)

      @enrollment = event && household.enrollment_for(event)
    end

    def love_box
      enrollment&.love_box_selection
    end

    def verified_by
      household.versions.where("object_changes -> 'verification_status' ->> 1 = 'verified'")
               .reorder(created_at: :desc, id: :desc).first&.actor
    end

    private

    def wishlists
      @wishlists ||= if event
        Figures.lists(event.wishlists.where(child_id: children.map(&:id))).index_by(&:child_id).each do |child_id, list|
          list.association(:child).target = children.find { |child| child.id == child_id }
        end
      else
        {}
      end
    end
  end
end
