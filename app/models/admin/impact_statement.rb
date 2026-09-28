# frozen_string_literal: true

module Admin
  # The January thank-you: one message to everyone whose gift to the event went through.
  class ImpactStatement
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :message, :string

    attr_accessor :event

    validates :message, presence: true, length: { maximum: 5000 }
    validate :somebody_to_send_to

    def recipients
      User.where(id: event.donations.succeeded.select(:donor_id))
    end

    def recipient_count
      @recipient_count ||= recipients.count
    end

    def deliver
      return false unless valid?

      recipients.find_each { |donor| DonorMailer.impact_statement(donor, event, message).deliver_later }
      true
    end

    private

    def somebody_to_send_to
      errors.add(:base, "No donor has a completed gift to this event yet") if recipient_count.zero?
    end
  end
end
