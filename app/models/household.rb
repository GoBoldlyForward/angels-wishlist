# frozen_string_literal: true

class Household < ApplicationRecord
  extend FriendlyId
  include PgSearch::Model
  acts_as_paranoid
  has_paper_trail only: %i[verification_status verified_at hold_reason]

  belongs_to :organization
  belongs_to :placing_organization, class_name: "Organization", optional: true
  belongs_to :caregiver, class_name: "User"
  belongs_to :mailing_address, class_name: "Address", optional: true

  has_many :children, dependent: :destroy
  has_many :wishlists, through: :children
  has_many :line_items, through: :wishlists
  has_many :payouts, dependent: :destroy

  accepts_nested_attributes_for :children, allow_destroy: true
  accepts_nested_attributes_for :mailing_address, update_only: true

  pg_search_scope :search, against: %i[display_name county],
                  associated_against: { caregiver: %i[first_name last_name email] },
                  using: { tsearch: { prefix: true } }

  friendly_id :display_name, use: :slugged

  enum :verification_status, { pending: "pending", verified: "verified", hold: "hold" },
       prefix: :verification, validate: true
  enum :payout_method, { none: "none", stripe: "stripe", gift_card: "gift_card" },
       prefix: :payout_via, validate: true

  scope :archived, -> { where.not(archived_at: nil) }
  scope :active, -> { where(archived_at: nil) }

  validates :display_name, presence: true
  validates :hold_reason, presence: true, if: :verification_hold?

  def raised_in_cents(event)
    line_items.funded.joins(:wishlist).where(wishlists: { event_id: event.id }).sum(:price_in_cents)
  end

  def asked_in_cents(event)
    line_items.joins(:wishlist).where(wishlists: { event_id: event.id }).sum(:price_in_cents)
  end

  def percent_funded(event)
    asked = asked_in_cents(event)
    return 0 if asked.zero?

    ((raised_in_cents(event).to_f / asked) * 100).round
  end

  # A payout is blocked by verification or by having nowhere to send money.
  def payout_status(event)
    return :hold if verification_hold?
    return :nomethod if payout_via_none?
    return :blocked unless verification_verified?

    payouts.find_by(event_id: event.id)&.status&.to_sym || :scheduled
  end

  def payable?
    verification_verified? && !payout_via_none?
  end

  def returning?
    wishlists.joins(:event).where(events: { organization_id: organization_id })
             .where.not(events: { id: organization.events.open_now.select(:id) }).exists?
  end

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current)
  end
end
