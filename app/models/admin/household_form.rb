# frozen_string_literal: true

module Admin
  # What staff fill in to add or edit a household: the caregiver, the home,
  # and how it is paid, saved together or not at all.
  class HouseholdForm
    include ActiveModel::Model

    CAREGIVER_FIELDS = %i[first_name last_name email phone preferred_language].freeze
    HOUSEHOLD_FIELDS = %i[display_name county placing_organization_id payout_method gift_card_email].freeze
    FIELDS = (CAREGIVER_FIELDS + HOUSEHOLD_FIELDS).freeze

    attr_accessor(*FIELDS)
    attr_reader :household, :caregiver

    def initialize(household, attributes = nil)
      @household = household
      @caregiver = household.caregiver || household.build_caregiver(role: "caregiver")
      super(current_values.merge((attributes || {}).to_h.symbolize_keys.slice(*FIELDS)))
    end

    def persisted?
      household.persisted?
    end

    # A new household is enrolled in the event it was added for, and its
    # caregiver is emailed a link to choose a password.
    def save(event: nil)
      adding = !persisted?
      assign
      return false unless all_valid?

      Household.transaction do
        caregiver.save!
        household.save!
        household.enrollments.find_or_create_by!(event: event) if event
      end
      caregiver.send_reset_password_instructions if adding
      true
    end

    def counties
      (Household::COUNTIES + [ county ]).compact_blank.uniq
    end

    def agencies
      Organization.agency.where(parent: household.organization).order(:name)
    end

    private

    def current_values
      caregiver.slice(*CAREGIVER_FIELDS).merge(household.slice(*HOUSEHOLD_FIELDS)).symbolize_keys
    end

    def assign
      caregiver.assign_attributes(CAREGIVER_FIELDS.index_with { |field| public_send(field).presence })
      # Devise wants a password on the row; the caregiver replaces this one through a reset link.
      caregiver.password = Devise.friendly_token(32) if caregiver.new_record?
      household.assign_attributes(HOUSEHOLD_FIELDS.index_with { |field| public_send(field).presence }
                                                  .merge(payout_method: payout_method.presence || "none"))
    end

    def all_valid?
      records = [ caregiver, household ]
      records.map(&:valid?)
      records.each { |record| record.errors.each { |error| errors.add(:base, error.full_message) } }
      errors.empty?
    end
  end
end
