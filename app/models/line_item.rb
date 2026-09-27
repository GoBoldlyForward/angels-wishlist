# frozen_string_literal: true

class LineItem < ApplicationRecord
  acts_as_paranoid
  has_paper_trail only: %i[status name price_in_cents spec link_url]

  MINIMUM_PRICE_IN_CENTS = 500
  LOCKED_ONCE_FUNDED = %w[name price_in_cents spec link_url catalog_item_id].freeze

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
  scope :listed, -> { where.not(status: "withdrawn") }
  scope :shoppable, -> { unfunded.open_status }
  scope :pooled, -> { where(spec: [ nil, "" ]) }
  scope :specific, -> { where.not(spec: [ nil, "" ]) }
  scope :oldest_first, -> { order(:created_at, :id) }
  scope :visible_to_donors, -> { open_status.where(wishlist_id: Wishlist.visible_to_donors.select(:id)) }

  validates :name, presence: true
  validates :price_in_cents, numericality: { greater_than_or_equal_to: MINIMUM_PRICE_IN_CENTS,
                                             message: "must be $5 or more" }
  validates :link_url, url: { allow_blank: true }
  validate :fits_under_the_cap, if: :counts_against_the_cap?
  validate :unchanged_once_funded, on: :update

  before_destroy :keep_if_funded
  after_save :send_list_back_for_review, if: :changed_by_caregiver?
  after_destroy :send_list_back_for_review, if: :caregiver_acting?

  def price_in_dollars
    price_in_cents / 100.0
  end

  def funded_at
    donation&.created_at
  end

  def funder_display_name
    return nil unless funded?

    donation.public_display_name
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

  def release!
    update!(donation: nil)
  end

  def approve!
    update!(status: "open")
  end

  def withdraw!
    update!(status: "withdrawn")
  end

  private

  def counts_against_the_cap?
    !withdrawn_status? && wishlist.present? && (new_record? || price_in_cents_changed? || status_changed?)
  end

  def fits_under_the_cap
    others = wishlist.line_items.listed.where.not(id: id).sum(:price_in_cents)
    cap = wishlist.event.per_child_cap_in_cents
    return if others + price_in_cents.to_i <= cap

    room = [ cap - others, 0 ].max
    errors.add(:price_in_cents, "would put this list over the $#{cap / 100} cap. $#{room / 100} left on it")
  end

  def unchanged_once_funded
    return if donation_id_was.blank? || (changed & LOCKED_ONCE_FUNDED).empty?

    errors.add(:base, "A funded gift cannot be changed")
  end

  def keep_if_funded
    return unless funded?

    errors.add(:base, "A funded gift cannot be removed")
    throw :abort
  end

  def caregiver_acting?
    Current.user&.caregiver? == true
  end

  def changed_by_caregiver?
    caregiver_acting? && (saved_changes.keys & (LOCKED_ONCE_FUNDED + %w[id status])).any?
  end

  def send_list_back_for_review
    wishlist.sent_back_by_caregiver_edit!
  end
end
