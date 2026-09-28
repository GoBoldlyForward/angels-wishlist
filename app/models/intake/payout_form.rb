# frozen_string_literal: true

module Intake
  # Step five: how the household is paid, where a gift card is mailed, and the
  # spending agreement.
  class PayoutForm
    include ActiveModel::Model
    include ActiveModel::Attributes
    include MailingAddress

    METHODS = %w[stripe gift_card].freeze
    LABELS = { street_line_1: "Mailing address", zipcode: "ZIP" }.freeze

    attribute :payout_method, :string
    attribute :agreed, :boolean, default: false

    attr_reader :enrollment

    delegate :household, to: :enrollment

    validates :payout_method, inclusion: { in: METHODS, message: "has to be chosen" }
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
        write_address_to(household) if gift_card?
        household.update!(payout_method: payout_method)
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
      household.stripe_account_id.present?
    end

    def self.human_attribute_name(attribute, options = {})
      LABELS[attribute.to_sym] || super
    end

    private

    def read_records
      self.payout_method = household.payout_method if METHODS.include?(household.payout_method)
      self.agreed = enrollment.spending_agreed?
      read_address_from(household)
    end

    def address_required?
      gift_card?
    end

    def stripe_is_connected
      errors.add(:base, "Connect with Stripe first, or choose the gift card in the mail.") unless connected?
    end

    def agreement_is_given
      return if agreed || enrollment.spending_agreed?

      errors.add(:base, "Check the box to agree to how the funds will be spent.")
    end
  end
end
