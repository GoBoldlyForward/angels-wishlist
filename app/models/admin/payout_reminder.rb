# frozen_string_literal: true

module Admin
  # One email to every household that sent lists in without finishing the Getting paid step.
  class PayoutReminder
    attr_reader :event

    def initialize(event)
      @event = event
    end

    def enrollments
      @enrollments ||= submitted.select { |enrollment| enrollment.payout_needs.any? }
    end

    def recipient_count
      enrollments.size
    end

    def last_sent_at
      enrollments.filter_map(&:payout_reminded_at).max
    end

    # Why the reminder cannot go out, or nil when it can.
    def refusal
      return "No household is waiting on the Getting paid step." if enrollments.empty?
      return "The Getting paid step is switched off, so caregivers have nowhere to choose." if switched_off?
      return "Lists are closed, so caregivers can no longer choose for themselves." if event.closed?

      nil
    end

    def deliver
      return false unless sendable?

      enrollments.each { |enrollment| CaregiverMailer.payout_needed(enrollment).deliver_later }
      Enrollment.where(id: enrollments.map(&:id)).update_all(payout_reminded_at: Time.current)
      true
    end

    def switched_off?
      !event.organization.collects_payout_details?
    end

    def sendable?
      refusal.nil?
    end

    private

    # A household on hold is not paid, so it is not asked.
    def submitted
      return [] unless event

      event.enrollments.submitted.joins(:household).merge(Household.active.not_verification_hold)
           .includes(household: :caregiver).to_a
    end
  end
end
