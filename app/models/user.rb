# frozen_string_literal: true

class User < ApplicationRecord
  extend FriendlyId
  acts_as_paranoid

  # A donor created at checkout has no password until they choose one, which is
  # what lets guest giving and a returning donor share one row.
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  belongs_to :organization, optional: true

  has_many :households, foreign_key: :caregiver_id, dependent: :restrict_with_error, inverse_of: :caregiver
  has_many :donations, foreign_key: :donor_id, dependent: :restrict_with_error, inverse_of: :donor
  has_many :children, through: :households
  has_many :organizations_contacted, class_name: "Organization", foreign_key: :primary_contact_id,
           dependent: :nullify, inverse_of: :primary_contact

  friendly_id :full_name, use: :slugged

  enum :role, { donor: "donor", caregiver: "caregiver", staff: "staff" }, validate: true

  scope :admins, -> { where(is_admin: true) }

  validates :first_name, :last_name, presence: true, if: :caregiver?
  validates :phone, phone: { allow_blank: true }
  validates :email, 'valid_email_2/email': { mx: false }

  def full_name
    [ first_name, last_name ].compact_blank.join(" ").presence || email
  end

  def initials
    [ first_name, last_name ].compact_blank.map { |n| n[0] }.join.upcase.presence || "?"
  end

  # Devise requires a password on a new record. A donor row created at checkout
  # has none, so it is skipped until they set one themselves.
  def password_required?
    return false if donor? && encrypted_password.blank?

    super
  end
end
