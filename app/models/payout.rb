# frozen_string_literal: true

class Payout < ApplicationRecord
  acts_as_paranoid
  has_paper_trail only: %i[status amount_in_cents hold_reason stripe_transfer_id gift_card_tracking_number]

  belongs_to :household
  belongs_to :event
  belongs_to :mailing_address, class_name: "Address", optional: true

  enum :method, { stripe: "stripe", gift_card: "gift_card" }, prefix: :via, validate: { allow_nil: true }
  enum :status, { blocked: "blocked", scheduled: "scheduled", sent: "sent", delivered: "delivered",
                  held: "held", failed: "failed" }, validate: true

  scope :payable, -> { where(status: %w[scheduled]) }
  scope :unsent, -> { where(status: %w[blocked scheduled held failed]) }

  validates :amount_in_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :hold_reason, presence: true, if: :held?

  def share_in_cents
    household.share_in_cents(event)
  end

  def amount_in_dollars
    amount_in_cents / 100.0
  end

  def destination
    via_stripe? ? household.stripe_account_id : mailing_address&.to_s
  end

  def blocker
    household.payout_blocker
  end

  def payable?
    scheduled? && amount_in_cents.positive? && household.payable?
  end

  # Brings the amount, method, and status in line with the household as it
  # stands now.
  def refresh!
    blocker = household.payout_blocker
    update!(
      amount_in_cents: share_in_cents,
      method: household.payout_via_none? ? nil : household.payout_method,
      mailing_address: household.payout_via_gift_card? ? household.mailing_address : nil,
      scheduled_for: event.payout_at,
      status: household.verification_hold? ? "held" : blocker ? "blocked" : "scheduled",
      hold_reason: blocker
    )
  end

  def mark_sent!(stripe_transfer_id: nil, gift_card_tracking_number: nil)
    update!(status: "sent", sent_at: Time.current, hold_reason: nil,
            stripe_transfer_id: stripe_transfer_id.presence || self.stripe_transfer_id,
            gift_card_tracking_number: gift_card_tracking_number.presence || self.gift_card_tracking_number)
  end

  def mark_delivered!
    update!(status: "delivered")
  end

  def mark_failed!(reason)
    update!(status: "failed", hold_reason: reason)
  end
end
