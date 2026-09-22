# frozen_string_literal: true

class CatalogItem < ApplicationRecord
  extend FriendlyId
  include PgSearch::Model
  acts_as_paranoid

  belongs_to :category

  has_many :line_items, dependent: :nullify

  has_one_attached :photo

  pg_search_scope :search, against: :name, using: { tsearch: { prefix: true } }

  friendly_id :name, use: :slugged

  scope :available, -> { where(active: true) }
  scope :for_age, ->(age) {
    where(arel_table[:min_age].lteq(age).or(arel_table[:min_age].eq(nil)))
      .where(arel_table[:max_age].gteq(age).or(arel_table[:max_age].eq(nil)))
  }

  validates :name, presence: true
  validates :price_in_cents, numericality: { greater_than: 0 }
  validates :photo, content_type: %w[image/png image/jpeg image/webp], size: { less_than: 10.megabytes }
  validate :ages_in_order

  def price_in_dollars
    price_in_cents / 100.0
  end

  def suits_age?(age)
    return true if age.blank?

    (min_age.nil? || age >= min_age) && (max_age.nil? || age <= max_age)
  end

  # A typed gift only joins a catalog tile on an unambiguous name match,
  # because a wrong guess puts one child's request inside another's counter.
  def self.unambiguous_match(typed_name)
    matches = available.where("LOWER(name) = ?", typed_name.to_s.strip.downcase).to_a
    matches.one? ? matches.first : nil
  end

  private

  def ages_in_order
    return if min_age.blank? || max_age.blank?

    errors.add(:max_age, "must be at or above the minimum age") if max_age < min_age
  end
end
