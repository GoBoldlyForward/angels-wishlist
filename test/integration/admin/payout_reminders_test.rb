# frozen_string_literal: true

require_relative "families_test_case"

module Admin
  class PayoutRemindersTest < FamiliesTestCase
    setup do
      @household, = build_family(name: "The Sinclair home", payout_method: "none", stripe_account_id: nil)
      @enrollment = enroll(@household)
      paid, = build_family
      enroll(paid)
    end

    test "Households says who is waiting and offers the reminder" do
      get admin_households_path

      assert_select ".privacy-note", /1 household\s+sent lists in without finishing the Getting paid step\.\s+No reminder has been sent yet\./
      assert_select ".privacy-note form[action=?] button", admin_payout_reminder_path, text: "Email them a reminder"
    end

    test "sending emails the households that are waiting and shows when it went" do
      assert_enqueued_emails 1 do
        post admin_payout_reminder_path
      end

      assert_redirected_to admin_households_path
      follow_redirect!
      assert_select ".alert", /The reminder is on its way to 1 household\./
      assert_select ".privacy-note", /A reminder was last sent #{Regexp.escape(I18n.l(Date.current, format: :long))}\./
    end

    test "a chapter with the step switched off is pointed at the switch instead" do
      @chapter.update!(collects_payout_details: false)

      get admin_households_path
      assert_select ".privacy-note", /The Getting paid step is switched off, so caregivers have nowhere to choose\./
      assert_select ".privacy-note a[href=?]", edit_admin_organization_path(@chapter), text: "Switch it on"
      assert_select ".privacy-note form", 0

      assert_no_enqueued_emails { post admin_payout_reminder_path }
      follow_redirect!
      assert_select ".alert", /The Getting paid step is switched off/
    end

    test "Households says nothing once every household is set up" do
      @household.update!(payout_method: "gift_card", gift_card_email: "denise@example.com")

      get admin_households_path

      assert_select ".privacy-note", 0
    end

    test "another chapter's staff cannot send this chapter's reminder" do
      sign_out @staff
      sign_in build_organizer(organization: build_organization)

      assert_no_enqueued_emails { post admin_payout_reminder_path }
      assert_nil @enrollment.reload.payout_reminded_at
    end
  end
end
