# frozen_string_literal: true

class Donation < ApplicationRecord
  acts_as_paranoid
  has_paper_trail only: %i[status note_approved_at],
                  meta: { organization_id: ->(donation) { donation.event.organization_id } }

  FEE_RATE = 0.03
  MINIMUM_GENERAL_GIFT_IN_CENTS = 500

  belongs_to :donor, class_name: "User"
  belongs_to :event
  belongs_to :storefront_organization, class_name: "Organization", optional: true

  has_many :line_items, dependent: :nullify

  enum :status, { pending: "pending", succeeded: "succeeded", refunded: "refunded",
                  disputed: "disputed", failed: "failed" }, validate: true

  scope :recent, -> { order(created_at: :desc) }
  scope :with_unapproved_note, -> { where.not(note_to_family: [ nil, "" ]).where(note_approved_at: nil) }
  scope :offline, -> { where(stripe_payment_intent_id: nil) }

  validates :gift_in_cents, :general_gift_in_cents, :fee_in_cents,
            numericality: { greater_than_or_equal_to: 0 }
  validates :note_to_family, length: { maximum: 1000 }
  validate :carries_some_money

  before_create :assign_uuid

  def charged_in_cents
    gift_in_cents + general_gift_in_cents + fee_in_cents
  end

  def charged_in_dollars
    charged_in_cents / 100.0
  end

  def given_in_cents
    gift_in_cents + general_gift_in_cents
  end

  def chosen_line_items
    LineItem.where(id: Array(cart["line_item_ids"]))
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

  def offline?
    stripe_payment_intent_id.blank?
  end

  def approve_note!
    update!(note_approved_at: Time.current)
  end

  def discard_note!
    update!(note_to_family: nil, note_approved_at: nil)
  end

  # Funds each chosen gift that is still open. One that somebody else funded
  # first stays in the pool as a general gift, so the amount given never changes.
  def settle!
    return self if succeeded?

    transaction do
      chosen_line_items.lock.order(:id).each do |line|
        if line.funded? || !line.open_status?
          self.gift_in_cents -= line.price_in_cents
          self.general_gift_in_cents += line.price_in_cents
        else
          line.fund!(self)
        end
      end
      update!(status: "succeeded")
    end
    self
  end

  def refund!
    transaction do
      line_items.find_each(&:release!)
      update!(status: "refunded")
    end
  end

  def mark_disputed!
    transaction do
      line_items.find_each(&:release!)
      update!(status: "disputed")
    end
  end

  def self.fee_for(cents)
    (cents * FEE_RATE).round
  end

  private

  def assign_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def carries_some_money
    return if gift_in_cents.to_i.positive? || general_gift_in_cents.to_i.positive?

    errors.add(:base, "A donation has to carry a gift or a general amount")
  end
end
