# frozen_string_literal: true

class Donation < ApplicationRecord
  acts_as_paranoid
  has_paper_trail only: %i[status note_approved_at],
                  meta: { organization_id: ->(donation) { donation.event.organization_id } }

  # What Stripe charges the platform for a card, the rate the application fee is estimated at.
  PROCESSING_BASIS_POINTS = 290
  PROCESSING_FIXED_IN_CENTS = 30
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

  validates :gift_in_cents, :general_gift_in_cents, :fee_in_cents, :platform_fee_in_cents, :processing_fee_in_cents,
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

  # Card processing and the platform fee, which Stripe keeps from the charge.
  def application_fee_in_cents
    platform_fee_in_cents + processing_fee_in_cents
  end

  # What reaches the families: the gift, less whatever of the application fee the donor did not cover.
  def pool_in_cents
    [ given_in_cents - [ application_fee_in_cents - fee_in_cents, 0 ].max, 0 ].max
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

  # The amount that lets a whole gift reach the families after processing and the platform fee.
  def self.fee_for(cents, platform_fee_basis_points: 0)
    return 0 unless cents.positive?

    kept = cents + platform_fee_for(cents, platform_fee_basis_points)
    charged = ((kept + PROCESSING_FIXED_IN_CENTS) / (1 - (PROCESSING_BASIS_POINTS / 10_000r))).floor
    charged += 1 while charged - processing_fee_for(charged) < kept
    charged - cents
  end

  def self.platform_fee_for(cents, basis_points)
    (cents * basis_points / 10_000r).round
  end

  def self.processing_fee_for(charged_in_cents)
    (charged_in_cents * PROCESSING_BASIS_POINTS / 10_000r).round + PROCESSING_FIXED_IN_CENTS
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
