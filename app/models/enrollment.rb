# frozen_string_literal: true

# What one household commits to for one event.
class Enrollment < ApplicationRecord
  acts_as_paranoid
  has_paper_trail only: %i[spending_agreed_at love_box submitted_at]

  INTAKE_STEPS = %w[home children love_box lists payout review].freeze

  belongs_to :household
  belongs_to :event

  scope :submitted, -> { where.not(submitted_at: nil) }

  validates :intake_step, inclusion: { in: INTAKE_STEPS }
  validates :household_id, uniqueness: { scope: :event_id }

  def love_box_selection
    LoveBox.new(self)
  end

  def wishlists
    event.wishlists.joins(:child).where(children: { household_id: household_id })
  end

  def step_number
    INTAKE_STEPS.index(intake_step) + 1
  end

  def spending_agreed?
    spending_agreed_at.present?
  end

  def submitted?
    submitted_at.present?
  end

  def reached?(step)
    INTAKE_STEPS.index(step.to_s) <= INTAKE_STEPS.index(intake_step)
  end

  def ready_to_submit?
    blockers.empty?
  end

  # Plain sentences saying what still stands between this household and
  # submitting, in the order the caregiver meets them.
  def blockers
    lists = wishlists.includes(:line_items).to_a
    [
      ("Add at least one child." if household.children.active.none?),
      ("Finish your Love Box." unless love_box_selection.complete?),
      ("Add at least one gift to every list." if lists.empty? || lists.any? { |list| list.line_items.listed.none? }),
      ("Choose how you would like to be paid." if household.payout_via_none?),
      ("Finish connecting with Stripe." if household.payout_via_stripe? && !household.stripe_connected?),
      ("Agree to how the funds will be spent." unless spending_agreed?)
    ].compact
  end

  def advance_to!(step)
    update!(intake_step: step.to_s) unless reached?(step)
  end

  def agree_to_spending!
    update!(spending_agreed_at: Time.current)
  end

  def submit!
    transaction do
      wishlists.where(status: "draft").find_each(&:submit!)
      update!(submitted_at: Time.current, intake_step: INTAKE_STEPS.last)
    end
  end
end
