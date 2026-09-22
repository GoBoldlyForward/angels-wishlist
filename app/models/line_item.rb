# frozen_string_literal: true

class LineItem < ApplicationRecord
  acts_as_paranoid

  belongs_to :wishlist
  belongs_to :catalog_item, optional: true
  belongs_to :donation, optional: true

  has_one :child, through: :wishlist
  has_one :event, through: :wishlist

  enum :status, { open: "open", needs_review: "needs_review", withdrawn: "withdrawn" },
       suffix: :status, validate: true

  # Funded is the presence of a donation, so "open" here means open and unfunded.
  scope :funded, -> { where.not(donation_id: nil) }
  scope :unfunded, -> { where(donation_id: nil) }
  scope :shoppable, -> { unfunded.open_status }
  scope :pooled, -> { where(spec: [ nil, "" ]) }
  scope :specific, -> { where.not(spec: [ nil, "" ]) }

  validates :name, presence: true
  validates :price_in_cents, numericality: { greater_than: 0 }
  validates :link_url, url: { allow_blank: true }

  def price_in_dollars
    price_in_cents / 100.0
  end

  def funded_at
    donation&.created_at
  end

  def funder_display_name
    return nil unless funded?

    donation.anonymous? ? "Anonymous" : donation.display_name
  end

  # A custom line the caregiver typed costs more than the catalog price, which
  # is the case staff are asked to confirm before it goes live.
  def above_catalog_price?
    catalog_item.present? && price_in_cents > catalog_item.price_in_cents
  end

  def funded?
    donation_id.present?
  end

  def custom?
    catalog_item_id.blank?
  end

  # A blank spec leaves the line in the pool, which any donor funding that
  # gift can cover. A spec gives the child their own line.
  def pooled?
    spec.blank?
  end

  def shoppable?
    !funded? && open_status? && wishlist.shoppable?
  end

  def fund!(donation)
    update!(donation: donation)
  end
end
