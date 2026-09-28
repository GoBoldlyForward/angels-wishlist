# frozen_string_literal: true

module Admin
  # What staff decide about one list, and the email each decision sends.
  class WishlistReview
    attr_reader :wishlist, :error

    delegate :household, :event, to: :wishlist

    def initialize(wishlist)
      @wishlist = wishlist
    end

    def approval_blocker
      return "#{household.display_name} has to be verified before its lists can go live." unless household.verification_verified?
      return "Only a list in review can be approved." unless wishlist.in_review?

      nil
    end

    def household_unverified?
      !household.verification_verified?
    end

    def approvable?
      approval_blocker.nil?
    end

    def returnable?
      wishlist.in_review? || wishlist.live?
    end

    def withdrawable?
      !wishlist.withdrawn?
    end

    def approve
      return refuse(approval_blocker) unless approvable?

      wishlist.approve!
      CaregiverMailer.lists_live(household, event).deliver_later if every_list_live?
      true
    rescue ActiveRecord::RecordInvalid => invalid
      refuse(invalid.record.errors.full_messages.to_sentence)
    end

    def return_to_caregiver(reason)
      return refuse("This list is not with staff, so there is nothing to return.") unless returnable?
      return refuse("Say what the caregiver needs to change.") if reason.blank?

      wishlist.return_to_caregiver!(reason.strip)
      CaregiverMailer.list_returned(wishlist).deliver_later
      true
    end

    def withdraw
      return refuse("This list is already withdrawn.") unless withdrawable?

      wishlist.withdraw!
      true
    end

    private

    def every_list_live?
      household.wishlists.where(event_id: event.id).where.not(status: %w[live withdrawn]).none?
    end

    def refuse(reason)
      @error = reason
      false
    end
  end
end
