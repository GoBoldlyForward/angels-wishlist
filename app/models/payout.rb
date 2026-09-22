# frozen_string_literal: true

class Payout < ApplicationRecord
  acts_as_paranoid

  belongs_to :household
  belongs_to :event
  belongs_to :mailing_address, class_name: "Address", optional: true

  enum :method, { stripe: "stripe", gift_card: "gift_card" }, prefix: :via, validate: true
  enum :status, { blocked: "blocked", scheduled: "scheduled", sent: "sent", delivered: "delivered",
                  held: "held", failed: "failed" }, validate: true

  scope :payable, -> { where(status: %w[scheduled]) }

  validates :amount_in_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :adjustment_note, presence: true, if: :overridden?
  validates :hold_reason, presence: true, if: :held?

  # What the household's lists actually raised. The payout defaults to this,
  # and any difference is a staff decision recorded in adjustment_note.
  def raised_in_cents
    household.raised_in_cents(event)
  end

  def top_up_in_cents
    [ amount_in_cents - raised_in_cents, 0 ].max
  end

  def amount_in_dollars
    amount_in_cents / 100.0
  end

  def destination
    via_stripe? ? household.stripe_account_id : mailing_address&.to_s
  end

  def overridden?
    amount_in_cents != raised_in_cents
  end

  def payable?
    scheduled? && amount_in_cents.positive? && household.payable?
  end

  def schedule!
    update!(status: "scheduled", scheduled_for: event.payout_at)
  end

  def mark_sent!
    update!(status: "sent", sent_at: Time.current)
  end
end
