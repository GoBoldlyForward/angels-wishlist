# frozen_string_literal: true

class Event < ApplicationRecord
  extend FriendlyId
  acts_as_paranoid

  belongs_to :organization

  has_many :wishlists, dependent: :destroy
  has_many :donations, dependent: :restrict_with_error
  has_many :payouts, dependent: :destroy
  has_many :line_items, through: :wishlists

  friendly_id :slug_candidate, use: :slugged

  scope :open_now, -> { where(arel_table[:opened_at].lteq(Time.current)).where(arel_table[:closes_at].gt(Time.current)) }

  validates :name, presence: true
  validates :per_child_cap_in_cents, numericality: { greater_than: 0 }
  validate :closes_after_it_opens

  # Phase is four dates read against now, never a stored column.
  def phase
    return :draft if opened_at.blank? || opened_at.future?
    return :open if closes_at.blank? || closes_at.future?
    return :closed if payout_at.blank? || payout_at.future?

    :paid_out
  end

  def per_child_cap_in_dollars
    per_child_cap_in_cents / 100.0
  end

  def days_remaining
    return nil if closes_at.blank?

    [ ((closes_at - Time.current) / 1.day).ceil, 0 ].max
  end

  def goal_in_cents
    line_items.sum(:price_in_cents)
  end

  def raised_in_cents
    line_items.funded.sum(:price_in_cents) + donations.succeeded.sum(:general_gift_in_cents)
  end

  def percent_funded
    return 0 if goal_in_cents.zero?

    ((raised_in_cents.to_f / goal_in_cents) * 100).round
  end

  def general_giving_pool_in_cents
    donations.succeeded.sum(:general_gift_in_cents)
  end

  # What is left of the pool after the top-ups staff have already approved.
  def unapplied_general_giving_in_cents
    spent = payouts.sum { |payout| payout.top_up_in_cents }
    [ general_giving_pool_in_cents - spent, 0 ].max
  end

  def open?
    phase == :open
  end

  def closed?
    %i[closed paid_out].include?(phase)
  end

  def slug_candidate
    "#{organization&.display_name} #{name}"
  end

  private

  def closes_after_it_opens
    return if opened_at.blank? || closes_at.blank?

    errors.add(:closes_at, "must be after the event opens") if closes_at <= opened_at
  end
end
