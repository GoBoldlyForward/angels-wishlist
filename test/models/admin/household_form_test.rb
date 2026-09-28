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
      assert_nil household.mailing_address
      assert_equal [ @event.id ], household.enrollments.pluck(:event_id)
    end

    test "nothing is saved when any part is invalid" do
      form = HouseholdForm.new(Household.new(organization: @chapter),
                               first_name: "Rosa", last_name: "Delgado", email: "rosa@example.com",
                               street_line_1: "12 Peachtree Way", city: "Atlanta", state: "GA", zipcode: "303")

      assert_no_emails do
        assert_no_difference [ "User.count", "Household.count", "Address.count", "Enrollment.count" ] do
          assert_not form.save(event: @event)
        end
      end
      assert_includes form.errors.full_messages, "Zipcode must be a 5 or 9 digit ZIP"
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

    test "clearing the address takes it off the household" do
      address = Address.create!(street_line_1: "1 Main St", city: "Atlanta", state: "GA", zipcode: "30303")
      household = build_household(organization: @chapter, mailing_address: address)
      form = HouseholdForm.new(household, street_line_1: "", city: "", zipcode: "")

      assert form.save
      assert_nil household.reload.mailing_address
    end
  end
end
