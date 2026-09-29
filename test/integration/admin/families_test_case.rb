# frozen_string_literal: true

require "test_helper"
require "csv"

module Admin
  # A chapter with one open event and a signed-in staff user, which is what
  # every Families, Inbox, and audit page starts from.
  class FamiliesTestCase < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include ActionMailer::TestHelper

    setup do
      @chapter = build_organization(name: "Atlanta Angels")
      @event = build_event(organization: @chapter, love_box_options: LoveBox::DEFAULT_GROUPS)
      @staff = users(:admin)
      sign_in @staff
    end

    private

    def build_family(name: "The Brooks home", alias_name: "Maya", list_status: "live", **household_attrs)
      household = build_household(organization: @chapter, display_name: name, **household_attrs)
      child = build_child(household: household, display_name: alias_name, legal_first_name: "Jordan")
      wishlist = build_wishlist(child: child, event: @event, status: list_status, interests: %w[drawing soccer],
                                caregiver_note: "She fills a sketchbook a month.")
      [ household, wishlist ]
    end

    def enroll(household, picks: {}, submitted: true)
      enrollment = Enrollment.new(household: household, event: @event, spending_agreed_at: Time.current,
                                  submitted_at: (Time.current if submitted))
      enrollment.love_box_selection.assign(picks)
      enrollment.save!
      enrollment
    end

    def csv_rows
      assert_equal "text/csv", response.media_type
      CSV.parse(response.body, headers: true).each.to_a
    end

    def assert_recorded_by_staff(record, field, change)
      version = record.versions.reorder(:id).last
      assert_equal @staff, version.actor
      assert_equal change, version.changeset[field]
    end
  end
end
