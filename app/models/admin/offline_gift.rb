# frozen_string_literal: true

module Admin
  # A check or cash gift staff record by hand. It joins the pool as a general gift.
  class OfflineGift
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :donor_name, :string
    attribute :email, :string
    attribute :amount_in_dollars, :string
    attribute :given_on, :date, default: -> { Date.current }
    attribute :payment_method_label, :string, default: "Check"
    attribute :display_name, :string
    attribute :anonymous, :boolean, default: false

    attr_accessor :event
    attr_reader :donation

    validates :donor_name, :email, :given_on, :payment_method_label, presence: true
    validates :given_on, comparison: { less_than_or_equal_to: -> { Date.current }, message: "cannot be in the future" },
                         allow_nil: true
    validate :amount_meets_the_minimum

    def amount_in_cents
      Dollars.to_cents(amount_in_dollars)
    end

    def save
      return false unless valid?

      Donation.transaction do
        @donation = Donation.create!(donor: find_or_create_donor, event: event, status: "succeeded",
                                     general_gift_in_cents: amount_in_cents, anonymous: anonymous,
                                     payment_method_label: payment_method_label,
                                     display_name: display_name.presence || donor_name, created_at: given_at)
      end
      true
    rescue ActiveRecord::RecordInvalid => e
      e.record.errors.each { |error| errors.add(:base, error.full_message) }
      false
    end

    private

    def find_or_create_donor
      first_name, last_name = donor_name.strip.split(/\s+/, 2)
      User.find_by(email: email.strip.downcase) ||
        User.create!(email: email.strip.downcase, role: "donor", first_name: first_name, last_name: last_name)
    end

    # Today's gifts keep the time they were entered so the ledger stays in order.
    def given_at
      given_on == Date.current ? Time.current : given_on.in_time_zone.middle_of_day
    end

    def amount_meets_the_minimum
      return if amount_in_cents.to_i >= Donation::MINIMUM_GENERAL_GIFT_IN_CENTS

      errors.add(:amount_in_dollars, "must be $5 or more")
    end
  end
end
