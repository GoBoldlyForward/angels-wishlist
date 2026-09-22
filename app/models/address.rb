# frozen_string_literal: true

class Address < ApplicationRecord
  has_many :households, foreign_key: :mailing_address_id, dependent: :nullify, inverse_of: :mailing_address
  has_many :organizations, foreign_key: :mailing_address_id, dependent: :nullify, inverse_of: :mailing_address
  has_many :payouts, foreign_key: :mailing_address_id, dependent: :nullify, inverse_of: :mailing_address

  validates :street_line_1, :city, :state, :zipcode, presence: true
  validates :zipcode, format: { with: /\A\d{5}(-\d{4})?\z/, message: "must be a 5 or 9 digit ZIP" }, allow_blank: true

  def to_s
    [ street_line_1, street_line_2, "#{city}, #{state} #{zipcode}".strip ].compact_blank.join(", ")
  end

  def city_state
    [ city, state ].compact_blank.join(", ")
  end
end
