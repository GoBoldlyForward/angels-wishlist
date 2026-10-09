# frozen_string_literal: true

class Household < ApplicationRecord
  extend FriendlyId
  include PgSearch::Model
  acts_as_paranoid
  has_paper_trail only: %i[verification_status verified_at hold_reason payout_method stripe_account_id
                           stripe_onboarded_at gift_card_email],
                  meta: { organization_id: :organization_id }

  COUNTIES = [ "Cherokee", "Clayton", "Cobb", "DeKalb", "Douglas", "Fayette", "Forsyth", "Fulton", "Gwinnett",
               "Henry", "Rockdale" ].freeze

  belongs_to :organization
  belongs_to :placing_organization, class_name: "Organization", optional: true
  belongs_to :caregiver, class_name: "User"

  has_many :children, dependent: :destroy
  has_many :wishlists, through: :children
  has_many :line_items, through: :wishlists
  has_many :enrollments, dependent: :destroy
  has_many :payouts, dependent: :destroy

  accepts_nested_attributes_for :children, allow_destroy: true

  pg_search_scope :search, against: %i[display_name county],
                  associated_against: { caregiver: %i[first_name last_name email] },
                  using: { tsearch: { prefix: true } }

  friendly_id :display_name, use: :slugged

  normalizes :gift_card_email, with: ->(email) { email.strip.downcase.presence }

  enum :verification_status, { pending: "pending", verified: "verified", hold: "hold" },
       prefix: :verification, validate: true
  enum :payout_method, { none: "none", stripe: "stripe", gift_card: "gift_card" },
       prefix: :payout_via, validate: true

  scope :archived, -> { where.not(archived_at: nil) }
  scope :active, -> { where(archived_at: nil) }

  validates :display_name, presence: true
  validates :hold_reason, presence: true, if: :verification_hold?
  validates :gift_card_email, 'valid_email_2/email': { mx: false }, allow_blank: true

  before_validation :name_after_caregiver, on: :create

  # What donors chose from this household's lists. It drives what staff see,
  # not what the household is paid.
  def chosen_in_cents(event)
    line_items.funded.joins(:wishlist).where(wishlists: { event_id: event.id }).sum(:price_in_cents)
  end

  def asked_in_cents(event)
    line_items.listed.joins(:wishlist).where(wishlists: { event_id: event.id }).sum(:price_in_cents)
  end

  def share_in_cents(event)
    wishlists.where(event_id: event.id).pluck(:id).sum { |id| event.shares.fetch(id, 0) }
  end

  def enrollment_for(event)
    enrollments.find_by(event_id: event.id)
  end

  # A payout is blocked by verification or by having nowhere to send money.
  def payout_status(event)
    return :hold if verification_hold?
    return :nomethod if payout_via_none?
    return :blocked unless verification_verified?

    payouts.find_by(event_id: event.id)&.status&.to_sym || :scheduled
  end

  def payout_blocker
    return hold_reason if verification_hold?
    return "Verification has not cleared." unless verification_verified?
    return "No payout method on file." if payout_via_none?
    return "Stripe onboarding is not finished." if payout_via_stripe? && !stripe_connected?
    return "No email address for the gift card." if payout_via_gift_card? && gift_card_email.blank?

    nil
  end

  def stripe_connected?
    stripe_onboarded_at.present?
  end

  def payable?
    payout_blocker.nil?
  end

  def returning?
    wishlists.joins(:event).where(events: { organization_id: organization_id })
             .where.not(events: { id: organization.events.open_now.select(:id) }).exists?
  end

  def archived?
    archived_at.present?
  end

  def verify!
    update!(verification_status: "verified", verified_at: Time.current, hold_reason: nil)
  end

  def hold!(reason)
    update!(verification_status: "hold", hold_reason: reason)
  end

  def archive!
    update!(archived_at: Time.current)
  end

  private

  def name_after_caregiver
    return if display_name.present? || caregiver&.last_name.blank?

    self.display_name = "The #{caregiver.last_name} home"
  end
end
