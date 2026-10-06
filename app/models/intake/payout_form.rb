# frozen_string_literal: true

module Intake
  # Step five: how the household is paid, where a gift card is emailed, and the
  # spending agreement.
  class PayoutForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    METHODS = %w[stripe gift_card].freeze
    LABELS = { gift_card_email: "Email for the gift card" }.freeze

    attribute :payout_method, :string
    attribute :gift_card_email, :string
    attribute :agreed, :boolean, default: false

    attr_reader :enrollment

    delegate :household, to: :enrollment

    validates :payout_method, inclusion: { in: METHODS, message: "has to be chosen" }
    validates :gift_card_email, presence: true, 'valid_email_2/email': { mx: false }, if: :gift_card?
    validate :stripe_is_connected, if: :stripe?
    validate :agreement_is_given

    def initialize(enrollment:, attributes: nil)
      @enrollment = enrollment
      super()
      read_records
      assign_attributes(attributes) if attributes
    end

    def save
      return false unless valid?

      ActiveRecord::Base.transaction do
        household.update!(payout_method: payout_method, **(gift_card? ? { gift_card_email: gift_card_email } : {}))
        enrollment.agree_to_spending! unless enrollment.spending_agreed?
      end
      true
    rescue ActiveRecord::RecordInvalid => e
      errors.add(:base, e.record.errors.full_messages.to_sentence)
      false
    end

    def stripe?
      payout_method == "stripe"
    end

    def gift_card?
      payout_method == "gift_card"
    end

    def connected?
      household.stripe_connected?
    end

    def connection_started?
      household.stripe_account_id.present? && !connected?
    end

    def gift_card_email=(value)
      super(value.to_s.strip.presence)
    end

    def self.human_attribute_name(attribute, options = {})
      LABELS[attribute.to_sym] || super
    end

    private

    def read_records
      self.payout_method = household.payout_method if METHODS.include?(household.payout_method)
      self.gift_card_email = household.gift_card_email.presence || household.caregiver.email
      self.agreed = enrollment.spending_agreed?
    end

    def stripe_is_connected
      return if connected?

      first = connection_started? ? "Finish connecting with Stripe" : "Connect with Stripe first"
      errors.add(:base, "#{first}, or choose the gift card by email.")
    end

    def agreement_is_given
      return if agreed || enrollment.spending_agreed?

      errors.add(:base, "Check the box to agree to how the funds will be spent.")
    end
  end
end
