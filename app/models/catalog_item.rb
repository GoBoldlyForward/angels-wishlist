# frozen_string_literal: true

class CatalogItem < ApplicationRecord
  extend FriendlyId
  include PgSearch::Model
  acts_as_paranoid

  belongs_to :organization
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
  validate :category_in_same_chapter

  before_validation :take_chapter_from_category

  def price_in_dollars
    price_in_cents / 100.0
  end

  # Lines donors can fund right now, oldest first.
  def open_line_items
    line_items.visible_to_donors.unfunded.oldest_first
  end

  def suits_age?(age)
    return true if age.blank?

    (min_age.nil? || age >= min_age) && (max_age.nil? || age <= max_age)
  end

  # A typed gift only joins a catalog tile on an unambiguous name match,
  # because a wrong guess puts one child's request inside another's counter.
  def self.unambiguous_match(typed_name)
    typed = typed_name.to_s.strip.downcase
    return nil if typed.length < 3

    matches = available.select do |item|
      name = item.name.downcase
      name == typed || name.start_with?("#{typed} ") || name.include?(" #{typed} ") || typed.include?(name)
    end
    matches.one? ? matches.first : nil
  end

  private

  def take_chapter_from_category
    self.organization ||= category&.organization
  end

  def category_in_same_chapter
    return if category.nil? || category.organization_id == organization_id

    errors.add(:category, "belongs to another chapter")
  end

  def ages_in_order
    return if min_age.blank? || max_age.blank?

    errors.add(:max_age, "must be at or above the minimum age") if max_age < min_age
  end
end
