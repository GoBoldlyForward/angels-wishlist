# frozen_string_literal: true

class Organization < ApplicationRecord
  extend FriendlyId
  acts_as_paranoid

  belongs_to :parent, class_name: "Organization", optional: true
  belongs_to :primary_contact, class_name: "User", optional: true
  belongs_to :mailing_address, class_name: "Address", optional: true

  has_many :children_organizations, class_name: "Organization", foreign_key: :parent_id,
           dependent: :nullify, inverse_of: :parent
  has_many :organization_memberships, dependent: :destroy
  has_many :organizers, through: :organization_memberships, source: :user
  has_many :events, dependent: :destroy
  has_many :households, dependent: :destroy
  has_many :placed_households, class_name: "Household", foreign_key: :placing_organization_id,
           dependent: :nullify, inverse_of: :placing_organization
  has_many :categories, dependent: :destroy
  has_many :catalog_items, dependent: :destroy

  has_one_attached :logo

  friendly_id :name, use: :slugged

  normalizes :hostname, with: ->(host) { host.strip.downcase.sub(%r{\Ahttps?://}, "").delete_suffix("/").presence }

  enum :kind, { chapter: "chapter", agency: "agency", partner: "partner" }, validate: true

  scope :hosting, -> { where(kind: %w[chapter partner]) }

  validates :name, presence: true
  validates :website_url, url: { allow_blank: true }
  validates :logo, content_type: %w[image/png image/jpeg image/svg+xml], size: { less_than: 5.megabytes }
  validates :hostname, uniqueness: { allow_nil: true },
                       format: { with: /\A[a-z0-9.-]+(:\d+)?\z/, allow_nil: true, message: "is a host name like wishlist.example.org" }
  validates :ein, format: { with: /\A\d{2}-\d{7}\z/, allow_blank: true, message: "is nine digits written 12-3456789" }
  validates :platform_fee_basis_points, numericality: { only_integer: true, in: 0..2_000 }

  def display_name
    short_name.presence || name
  end

  def ancestors
    parent ? [ parent ] + parent.ancestors : []
  end

  # The name a donor's receipt and the tax language carry.
  def legal_name_or_name
    legal_name.presence || name
  end

  # The chapter a partner or agency works under, or the chapter itself.
  def chapter
    chapter? ? self : parent&.chapter
  end

  # A new chapter starts from another chapter's categories and catalog rather than an empty shop.
  def copy_catalog_from(source)
    transaction do
      source.categories.ordered.includes(catalog_items: { photo_attachment: :blob }).each do |category|
        copy = categories.create!(category.slice(:name, :icon, :tint, :headline, :blurb, :position))
        category.catalog_items.each do |item|
          copied = catalog_items.create!(item.slice(:name, :price_in_cents, :min_age, :max_age, :icon, :active,
                                                    :stock_photo, :photo_attribution).merge(category: copy))
          copied.photo.attach(item.photo.blob) if item.photo.attached?
        end
      end
    end
  end

  def hosts_drives?
    chapter? || partner?
  end

  # Visitors reach a chapter by its host name; a host no chapter claims reaches the oldest one.
  def self.chapter_for_host(host)
    chapter.find_by(hostname: host.to_s.downcase) || chapter.order(:id).first
  end
end
