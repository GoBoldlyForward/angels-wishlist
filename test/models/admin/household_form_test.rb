# frozen_string_literal: true

require "test_helper"

module Admin
  class HouseholdFormTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

    setup do
      @chapter = build_organization
      @event = build_event(organization: @chapter)
    end

    test "a new household is named after its caregiver, waits for verification, and is enrolled" do
      form = HouseholdForm.new(Household.new(organization: @chapter),
                               first_name: "Rosa", last_name: "Delgado", email: "rosa@example.com")

      assert form.save(event: @event)
      household = form.household.reload
      assert_equal "The Delgado home", household.display_name
      assert household.verification_pending?
      assert household.payout_via_none?
      assert household.caregiver.caregiver?
      assert_nil household.gift_card_email
      assert_equal [ @event.id ], household.enrollments.pluck(:event_id)
    end

    test "nothing is saved when any part is invalid" do
      form = HouseholdForm.new(Household.new(organization: @chapter),
                               first_name: "Rosa", last_name: "Delgado", email: "rosa@example.com",
                               payout_method: "gift_card", gift_card_email: "rosa at example")

      assert_no_emails do
        assert_no_difference [ "User.count", "Household.count", "Enrollment.count" ] do
          assert_not form.save(event: @event)
        end
      end
      assert_includes form.errors.full_messages, "Gift card email is invalid"
    end

    test "an email already in use is refused" do
      taken = build_caregiver

      form = HouseholdForm.new(Household.new(organization: @chapter),
                               first_name: "Rosa", last_name: "Delgado", email: taken.email)

      assert_not form.save(event: @event)
      assert_includes form.errors.full_messages, "Email has already been taken"
    end

    test "editing keeps the caregiver's password and sends no email" do
      household = build_household(organization: @chapter)
      form = HouseholdForm.new(household, first_name: "Denise", last_name: "Brooks-Hale",
                                          email: household.caregiver.email, display_name: household.display_name,
                                          payout_method: "stripe")

      assert_no_emails { assert form.save }
      assert_equal "Brooks-Hale", household.caregiver.reload.last_name
      assert household.caregiver.valid_password?("password123")
    end

    test "clearing the gift card email takes it off the household" do
      household = build_household(organization: @chapter, gift_card_email: "cards@example.com")
      form = HouseholdForm.new(household, gift_card_email: "")

      assert form.save
      assert_nil household.reload.gift_card_email
    end
  end
end
