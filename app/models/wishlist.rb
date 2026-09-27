# frozen_string_literal: true

class Wishlist < ApplicationRecord
  extend FriendlyId
  acts_as_paranoid
  has_paper_trail only: %i[status submitted_at approved_at caregiver_note interests review_note]

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
  # Public only when the list is live, its event is open, and its household is verified.
  scope :visible_to_donors, -> {
    where(status: "live").joins(:event, child: :household)
                         .merge(Event.open_now)
                         .where(children: { archived_at: nil })
                         .where(households: { verification_status: "verified", archived_at: nil })
  }

  validates :caregiver_note, length: { maximum: 400 }

  # A caregiver editing a live list sends it back for review rather than
  # publishing the change straight to donors.
  before_update :return_to_review, if: :content_changed_while_live?

  def asked_in_cents
    line_items.listed.sum(:price_in_cents)
  end

  def chosen_in_cents
    line_items.funded.sum(:price_in_cents)
  end

  def remaining_in_cents
    [ asked_in_cents - chosen_in_cents, 0 ].max
  end

  def percent_chosen
    return 0 if asked_in_cents.zero?

    ((chosen_in_cents.to_f / asked_in_cents) * 100).round
  end

  def share_in_cents
    event.share_for(self)
  end

  def room_in_cents
    [ event.per_child_cap_in_cents - asked_in_cents, 0 ].max
  end

  def open_line_items
    line_items.shoppable
  end

  def slug_candidate
    "#{child&.display_name} #{event&.name}"
  end

  # A typed gift joins a catalog product only when one name fits. A price
  # above the catalog's waits for staff before donors see it.
  def add_gift(name:, price_in_cents:, link_url: nil)
    match = CatalogItem.unambiguous_match(name)
    above = match.present? && price_in_cents.to_i > match.price_in_cents
    line_items.create(name: name.to_s.strip, price_in_cents: price_in_cents, link_url: link_url.presence,
                      catalog_item: match, status: above ? "needs_review" : "open")
  end

  def at_cap?
    room_in_cents.zero?
  end

  def fully_chosen?
    line_items.listed.any? && line_items.shoppable.none?
  end

  def shoppable?
    live? && event.open? && household.verification_verified? && !household.archived? && !child.archived?
  end

  def editable_by_caregiver?
    !event.closed? && !withdrawn? && !closed?
  end

  def submit!
    update!(status: "in_review", submitted_at: Time.current, review_note: nil)
  end

  def approve!
    transaction do
      line_items.needs_review_status.find_each(&:approve!)
      update!(status: "live", approved_at: Time.current, review_note: nil)
    end
  end

  def return_to_caregiver!(reason)
    update!(status: "draft", approved_at: nil, review_note: reason)
  end

  def withdraw!
    update!(status: "withdrawn")
  end

  def sent_back_by_caregiver_edit!
    update!(status: "in_review", approved_at: nil) if live?
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
