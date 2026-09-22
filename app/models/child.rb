# frozen_string_literal: true

class Child < ApplicationRecord
  acts_as_paranoid

  belongs_to :household

  has_many :wishlists, dependent: :destroy
  has_many :line_items, through: :wishlists

  accepts_nested_attributes_for :wishlists, allow_destroy: true

  enum :gender, { girl: "girl", boy: "boy", unspecified: "unspecified" }, validate: true

  scope :active, -> { where(archived_at: nil) }

  validates :display_name, presence: true

  # Age is read off the birthdate so a list never quietly ages wrong mid-season.
  def age
    return nil if birthdate.blank?

    today = Date.current
    today.year - birthdate.year - (today.strftime("%m%d") < birthdate.strftime("%m%d") ? 1 : 0)
  end

  def wishlist_for(event)
    wishlists.find_by(event_id: event.id)
  end

  def to_s
    age ? "#{display_name}, #{age}" : display_name
  end

  def archived?
    archived_at.present?
  end
end
