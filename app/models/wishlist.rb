# frozen_string_literal: true

class Wishlist < ApplicationRecord
  extend FriendlyId
  acts_as_paranoid

  belongs_to :child
  belongs_to :event

  has_one :household, through: :child
  has_many :line_items, dependent: :destroy

  accepts_nested_attributes_for :line_items, allow_destroy: true

  friendly_id :slug_candidate, use: :slugged

  enum :status, { draft: "draft", in_review: "in_review", live: "live", closed: "closed",
                  withdrawn: "withdrawn" }, validate: true

  scope :shoppable, -> { where(status: "live") }
  scope :needing_review, -> { where(status: "in_review") }

  validates :caregiver_note, length: { maximum: 400 }

  # A caregiver editing a live list sends it back for review rather than
  # publishing the change straight to donors.
  before_update :return_to_review, if: :content_changed_while_live?

  def asked_in_cents
    line_items.sum(:price_in_cents)
  end

  def raised_in_cents
    line_items.funded.sum(:price_in_cents)
  end

  def remaining_in_cents
    [ asked_in_cents - raised_in_cents, 0 ].max
  end

  def percent_funded
    return 0 if asked_in_cents.zero?

    ((raised_in_cents.to_f / asked_in_cents) * 100).round
  end

  def open_line_items
    line_items.open_status
  end

  def over_cap?
    asked_in_cents > event.per_child_cap_in_cents
  end

  def fully_funded?
    line_items.any? && line_items.open_status.none?
  end

  def shoppable?
    live? && event.open?
  end

  def slug_candidate
    "#{child&.display_name} #{event&.name}"
  end

  def submit!
    update!(status: "in_review", submitted_at: Time.current)
  end

  def approve!
    update!(status: "live", approved_at: Time.current)
  end

  private

  def content_changed_while_live?
    status_was == "live" && !status_changed? &&
      (caregiver_note_changed? || interests_changed?)
  end

  def return_to_review
    self.status = "in_review"
    self.approved_at = nil
  end
end
