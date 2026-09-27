# frozen_string_literal: true

module Intake
  # The three address fields a caregiver types, shared by the steps that ask for them.
  module MailingAddress
    extend ActiveSupport::Concern

    STATE = "GA"
    FIELDS = %i[street_line_1 city zipcode].freeze

    included do
      attribute :street_line_1, :string
      attribute :city, :string
      attribute :zipcode, :string

      validates :street_line_1, :city, :zipcode, presence: true, if: :address_required?
      validates :zipcode, format: { with: /\A\d{5}(-\d{4})?\z/, message: "must be 5 or 9 digits" },
                          allow_blank: true, if: :address_required?
    end

    def address_given?
      FIELDS.any? { |field| public_send(field).present? }
    end

    private

    def address_required?
      address_given?
    end

    def read_address_from(household)
      address = household&.mailing_address
      return if address.nil?

      FIELDS.each { |field| public_send("#{field}=", address.public_send(field)) }
    end

    def write_address_to(household)
      return household.update!(mailing_address: nil) unless address_given?

      address = household.mailing_address || Address.new
      address.update!(street_line_1: street_line_1.strip, city: city.strip, state: STATE, zipcode: zipcode.strip)
      household.update!(mailing_address: address)
    end
  end
end
