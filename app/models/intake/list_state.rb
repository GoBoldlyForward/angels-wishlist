# frozen_string_literal: true

module Intake
  # Where one child's list stands, in the words a caregiver reads.
  class ListState
    LABELS = { returned: "Needs a change", draft: "Not sent in yet", in_review: "In review", live: "Live",
               closed: "Closed", withdrawn: "Withdrawn" }.freeze
    EXPLANATIONS = {
      returned: "Staff sent this list back. Make the change and send it in again.",
      draft: "Donors cannot see this list until you send it in.",
      in_review: "Staff are looking it over. Donors see it once it is approved.",
      live: "Donors can see this list and give toward it.",
      closed: "Giving has ended for this list.",
      withdrawn: "This list was taken down. Your coordinator can tell you more."
    }.freeze

    attr_reader :wishlist, :enrollment

    def initialize(wishlist, enrollment)
      @wishlist = wishlist
      @enrollment = enrollment
    end

    def key
      returned? ? :returned : wishlist.status.to_sym
    end

    def label
      LABELS.fetch(key)
    end

    def explanation
      EXPLANATIONS.fetch(key)
    end

    def returned?
      wishlist.draft? && wishlist.review_note.present? && enrollment.submitted?
    end

    def editable?
      wishlist.editable_by_caregiver?
    end

    def ready_to_send?
      wishlist.draft? && enrollment.submitted? && editable? && wishlist.line_items.listed.any?
    end
  end
end
