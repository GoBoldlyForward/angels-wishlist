# frozen_string_literal: true

class User < ApplicationRecord
  extend FriendlyId
  acts_as_paranoid

  # A donor created at checkout has no password until they choose one, which is
  # what lets guest giving and a returning donor share one row.
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :organization_memberships, dependent: :destroy
  has_many :organizations, through: :organization_memberships
  has_many :households, foreign_key: :caregiver_id, dependent: :restrict_with_error, inverse_of: :caregiver
  has_many :donations, foreign_key: :donor_id, dependent: :restrict_with_error, inverse_of: :donor
  has_many :children, through: :households
  has_many :organizations_contacted, class_name: "Organization", foreign_key: :primary_contact_id,
           dependent: :nullify, inverse_of: :primary_contact

  friendly_id :full_name, use: :slugged

  enum :role, { donor: "donor", caregiver: "caregiver", organizer: "organizer", admin: "admin" },
       validate: true

  scope :organizing, -> { where(role: %w[organizer admin]) }

  validates :first_name, :last_name, presence: true, if: :caregiver?
  validates :phone, phone: { allow_blank: true }
  validates :email, 'valid_email_2/email': { mx: false }

  def full_name
    [ first_name, last_name ].compact_blank.join(" ").presence || email
  end

  def initials
    [ first_name, last_name ].compact_blank.map { |n| n[0] }.join.upcase.presence || "?"
  end

  # An admin works across the whole system, so every organization that hosts a
  # drive is in reach without a membership row standing for it.
  def available_organizations
    admin? ? Organization.hosting.order(:name) : organizations.hosting.order(:name)
  end

  def organizes?(organization)
    return false if organization.blank?

    available_organizations.exists?(id: organization.id)
  end

  def organizes_anything?
    available_organizations.exists?
  end

  # Devise requires a password on a new record. A donor row created at checkout
  # has none, so it is skipped until they set one themselves.
  def password_required?
    return false if donor? && encrypted_password.blank?

    super
  end
end
