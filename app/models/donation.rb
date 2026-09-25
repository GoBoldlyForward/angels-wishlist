# frozen_string_literal: true

class Donation < ApplicationRecord
  acts_as_paranoid
  has_paper_trail only: %i[note_approved_at]

  belongs_to :donor, class_name: "User"
  belongs_to :event
  belongs_to :storefront_organization, class_name: "Organization", optional: true

  has_many :line_items, dependent: :nullify

  enum :status, { pending: "pending", succeeded: "succeeded", refunded: "refunded",
                  disputed: "disputed", failed: "failed" }, validate: true

  scope :recent, -> { order(created_at: :desc) }
  scope :with_unapproved_note, -> { where.not(note_to_family: [ nil, "" ]).where(note_approved_at: nil) }

  validates :gift_in_cents, :general_gift_in_cents, :fee_in_cents,
            numericality: { greater_than_or_equal_to: 0 }
  validates :note_to_family, length: { maximum: 1000 }
  validate :carries_some_money

  def charged_in_cents
    gift_in_cents + general_gift_in_cents + fee_in_cents
  end

  def charged_in_dollars
    charged_in_cents / 100.0
  end

  def households
    Household.joins(wishlists: :line_items).where(line_items: { id: line_items.select(:id) }).distinct
  end

  def public_display_name
    anonymous? ? "Anonymous" : display_name.presence || donor.full_name
  end

  def to_param
    uuid
  end

  def fee_covered?
    fee_in_cents.positive?
  end

  def designated?
    line_items.any?
  end

  def note_pending_review?
    note_to_family.present? && note_approved_at.blank?
  end

  def approve_note!
    update!(note_approved_at: Time.current)
  end

  private

  def carries_some_money
    return if gift_in_cents.positive? || general_gift_in_cents.positive?

    errors.add(:base, "A donation has to carry a gift or a general amount")
  end
end
