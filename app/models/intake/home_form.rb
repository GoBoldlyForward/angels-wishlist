# frozen_string_literal: true

module Intake
  # Step one: the caregiver's account, the household, its county, and its
  # place in this event.
  class HomeForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    LABELS = { phone: "Mobile number" }.freeze
    PHONE_COUNTRY = "US"

    attribute :first_name, :string
    attribute :last_name, :string
    attribute :email, :string
    attribute :password, :string
    attribute :phone, :string
    attribute :county, :string

    attr_reader :user, :household, :enrollment

    validates :first_name, :last_name, :email, presence: true
    validates :county, inclusion: { in: Household::COUNTIES, message: "must be chosen from the list" }
    validates :password, presence: true, length: { in: Devise.password_length }, if: :new_account?
    validate :email_has_no_account, if: :new_account?
    validate :phone_can_be_dialed, if: -> { phone.present? }

    def initialize(user:, organization:, event:, attributes: nil)
      @user = user || User.new(role: "caregiver")
      @organization = organization
      @event = event
      @household = self.class.household_of(@user, organization)
      super()
      attributes.nil? ? read_records : assign_attributes(attributes)
    end

    def save
      return false unless valid?

      ActiveRecord::Base.transaction do
        user.update!(account_attributes)
        @household ||= Household.new(organization: @organization, caregiver: user)
        household.update!(county: county)
        @enrollment = household.enrollments.find_or_create_by!(event: @event)
        enrollment.advance_to!(:children)
      end
      true
    rescue ActiveRecord::RecordInvalid => e
      e.record.errors.each { |error| errors.add(error.attribute, error.message) if respond_to?(error.attribute) }
      errors.add(:base, e.record.errors.full_messages.to_sentence) if errors.empty?
      false
    end

    def new_account?
      user.new_record?
    end

    def email_taken?
      new_account? && errors.of_kind?(:email, :taken)
    end

    def self.human_attribute_name(attribute, options = {})
      LABELS[attribute.to_sym] || super
    end

    def self.household_of(user, organization)
      return nil if user.new_record?

      user.households.active.where(organization: organization).order(:id).first
    end

    private

    def read_records
      assign_attributes(user.slice(:first_name, :last_name, :email))
      self.phone = parsed_phone(user.phone).national if user.phone.present?
      self.county = household&.county
    end

    def account_attributes
      account = { first_name: first_name, last_name: last_name, email: email,
                  phone: phone.present? ? parsed_phone(phone).e164 : nil }
      new_account? ? account.merge(password: password) : account
    end

    def parsed_phone(number)
      Phonelib.parse(number, PHONE_COUNTRY)
    end

    def email_has_no_account
      return unless User.with_deleted.exists?(email: email.to_s.strip.downcase)

      errors.add(:email, :taken, message: "already has an account")
    end

    def phone_can_be_dialed
      errors.add(:phone, "does not look like a phone number") unless parsed_phone(phone).valid?
    end
  end
end
