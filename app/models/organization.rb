# frozen_string_literal: true

class Organization < ApplicationRecord
  extend FriendlyId
  acts_as_paranoid

  belongs_to :parent, class_name: "Organization", optional: true
  belongs_to :primary_contact, class_name: "User", optional: true
  belongs_to :mailing_address, class_name: "Address", optional: true

  has_many :children_organizations, class_name: "Organization", foreign_key: :parent_id,
           dependent: :nullify, inverse_of: :parent
  has_many :staff, class_name: "User", dependent: :nullify, inverse_of: :organization
  has_many :events, dependent: :destroy
  has_many :households, dependent: :destroy
  has_many :placed_households, class_name: "Household", foreign_key: :placing_organization_id,
           dependent: :nullify, inverse_of: :placing_organization

  has_one_attached :logo

  friendly_id :name, use: :slugged

  enum :kind, { chapter: "chapter", agency: "agency", partner: "partner" }, validate: true

  scope :hosting, -> { where(kind: %w[chapter partner]) }

  validates :name, presence: true
  validates :website_url, url: { allow_blank: true }
  validates :logo, content_type: %w[image/png image/jpeg image/svg+xml], size: { less_than: 5.megabytes }

  # A partner drive still settles to the chapter that runs the event, so the
  # account is looked up through the tree rather than on the storefront.
  def settlement_account_id
    stripe_account_id.presence || parent&.settlement_account_id
  end

  def display_name
    short_name.presence || name
  end

  def ancestors
    parent ? [ parent ] + parent.ancestors : []
  end

  def hosts_drives?
    chapter? || partner?
  end
end
