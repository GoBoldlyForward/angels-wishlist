# frozen_string_literal: true

class Event < ApplicationRecord
  extend FriendlyId
  acts_as_paranoid

  belongs_to :organization

  has_many :wishlists, dependent: :destroy
  has_many :enrollments, dependent: :destroy
  has_many :donations, dependent: :restrict_with_error
  has_many :payouts, dependent: :destroy
  has_many :line_items, through: :wishlists

  friendly_id :slug_candidate, use: :slugged

  scope :open_now, -> { where(arel_table[:opened_at].lteq(Time.current)).where(arel_table[:closes_at].gt(Time.current)) }
  scope :newest_first, -> { order(opened_at: :desc, id: :desc) }

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

  def love_box_groups
    love_box_options.map { |row| LoveBox::Group.from(row) }
  end

  # The lists the pool is spread across. A household on hold keeps its place
  # so its share is waiting when the hold clears.
  def counted_wishlists
    wishlists.where(status: %w[live closed]).joins(child: :household)
             .where(children: { archived_at: nil })
             .where(households: { verification_status: %w[verified hold], archived_at: nil })
  end

  def goal_in_cents
    asked_by_wishlist.values.sum
  end

  def raised_in_cents
    donations.succeeded.sum(Arel.sql(<<~SQL.squish))
      GREATEST(gift_in_cents + general_gift_in_cents
               - GREATEST(platform_fee_in_cents + processing_fee_in_cents - fee_in_cents, 0), 0)
    SQL
  end

  def percent_funded
    return 0 if goal_in_cents.zero?

    ((raised_in_cents.to_f / goal_in_cents) * 100).round
  end

  def funded_ratio
    return 0r if goal_in_cents.zero?

    [ Rational(raised_in_cents, goal_in_cents), 1r ].min
  end

  def surplus_in_cents
    [ raised_in_cents - goal_in_cents, 0 ].max
  end

  # Every list is funded to the same percentage. Cents that rounding leaves
  # over go to the largest remainders so the shares add up to the pool.
  def shares
    @shares ||= begin
      asked = asked_by_wishlist
      pool = [ raised_in_cents, asked.values.sum ].min
      exact = asked.transform_values { |cents| asked.values.sum.zero? ? 0r : Rational(cents * pool, asked.values.sum) }
      floors = exact.transform_values(&:floor)
      leftover = pool - floors.values.sum
      bumped = exact.keys.sort_by { |id| [ -(exact[id] - floors[id]), id ] }.first(leftover)
      floors.to_h { |id, cents| [ id, bumped.include?(id) ? cents + 1 : cents ] }
    end
  end

  def share_for(wishlist)
    shares.fetch(wishlist.id, 0)
  end

  def reload(*)
    @shares = @asked_by_wishlist = nil
    super
  end

  def slug_candidate
    "#{organization&.display_name} #{name}"
  end

  def open?
    phase == :open
  end

  def closed?
    %i[closed paid_out].include?(phase)
  end

  # One payout per household with a counted list, for its share. Payouts
  # already sent are left alone.
  def build_payouts!
    @shares = @asked_by_wishlist = nil
    households = Household.where(id: counted_wishlists.select("children.household_id"))

    transaction do
      households.find_each do |household|
        payout = payouts.find_or_initialize_by(household: household)
        next if payout.sent? || payout.delivered?

        payout.refresh!
      end
    end
    payouts.reload
  end

  def self.current
    open_now.newest_first.first || newest_first.first
  end

  private

  def asked_by_wishlist
    @asked_by_wishlist ||= LineItem.listed.where(wishlist_id: counted_wishlists.select(:id))
                                   .group(:wishlist_id).sum(:price_in_cents)
                                   .then { |sums| counted_wishlists.pluck(:id).to_h { |id| [ id, sums.fetch(id, 0) ] } }
  end

  def closes_after_it_opens
    return if opened_at.blank? || closes_at.blank?

    errors.add(:closes_at, "must be after the event opens") if closes_at <= opened_at
  end
end
