# frozen_string_literal: true

class Child < ApplicationRecord
  acts_as_paranoid

  # Donors never see a legal first name, so the system assigns the stand-in
  # rather than asking a caregiver to invent one.
  ALIASES = %w[
    Maya Theo Nova Beau Rowan Sage Micah Wren Ezra Iris Juno Levi Nia Otis Poppy Quinn Reese Sol Tess Vera
    Arlo Bria Cody Dara Eli Faye Gus Hana Ivo Jade Kit Lena Milo Nell Omar Pia Remy Skye Tobi Una
    Abel Bex Cleo Dion Esme Finn Gia Hugo Isla Joss Kaia Lars Mina Nico Opal Penn Rio Suki Taj Zora
  ].freeze

  belongs_to :household

  has_many :wishlists, dependent: :destroy
  has_many :line_items, through: :wishlists

  accepts_nested_attributes_for :wishlists, allow_destroy: true

  enum :gender, { girl: "girl", boy: "boy", unspecified: "unspecified" }, validate: true

  scope :active, -> { where(archived_at: nil) }

  validates :display_name, presence: true
  validates :birthdate, comparison: { less_than_or_equal_to: -> { Date.current }, allow_nil: true }

  before_validation :assign_alias, on: :create

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

  def self.aliases_in_use(organization_id)
    active.joins(:household).where(households: { organization_id: organization_id }).pluck(:display_name)
  end

  private

  def assign_alias
    return if display_name.present? || household.blank?

    taken = self.class.aliases_in_use(household.organization_id) +
            household.children.reject(&:persisted?).filter_map(&:display_name)
    self.display_name = (ALIASES - taken).first || "Child #{taken.size + 1}"
  end
end
