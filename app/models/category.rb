# frozen_string_literal: true

class Category < ApplicationRecord
  extend FriendlyId
  acts_as_paranoid

  has_many :catalog_items, dependent: :restrict_with_error

  friendly_id :name, use: :slugged

  acts_as_list

  scope :ordered, -> { order(:position) }

  validates :name, presence: true

  def to_s
    name
  end
end
