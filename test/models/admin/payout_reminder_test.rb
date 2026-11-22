# frozen_string_literal: true

require "test_helper"

module Admin
  class PayoutReminderTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

    setup do
      @chapter = build_organization
      @event = build_event(organization: @chapter)
      @unpaid = enroll(build_household(organization: @chapter, payout_method: "none", stripe_account_id: nil))
    end

    test "it asks every household that sent lists in without a way to be paid or the agreement" do
      half_connected = enroll(build_household(organization: @chapter, stripe_account_id: "acct_started", stripe_onboarded_at: nil))
      not_agreed = enroll(build_household(organization: @chapter), spending_agreed_at: nil)
      enroll(build_household(organization: @chapter))

      assert_equal [ @unpaid, half_connected, not_agreed ].map(&:id).sort, PayoutReminder.new(@event).enrollments.map(&:id).sort
    end

    test "it leaves out households that have not sent lists in, are on hold, or are archived" do
      enroll(build_household(organization: @chapter, payout_method: "none"), submitted_at: nil)
      enroll(build_household(organization: @chapter, payout_method: "none", verification_status: "hold", hold_reason: "Placement changed."))
      enroll(build_household(organization: @chapter, payout_method: "none", archived_at: 1.day.ago))
      enroll(build_household(organization: @chapter, payout_method: "none"), event: build_event(organization: @chapter))

      assert_equal [ @unpaid ], PayoutReminder.new(@event).enrollments
    end

    test "delivering emails each household once and records when" do
      reminder = PayoutReminder.new(@event)

      freeze_time do
        assert_enqueued_email_with(CaregiverMailer, :payout_needed, args: [ @unpaid ]) { assert reminder.deliver }

        assert_equal Time.current, @unpaid.reload.payout_reminded_at
        assert_equal Time.current, PayoutReminder.new(@event).last_sent_at
      end
    end

    test "it is not sent while the Getting paid step is switched off" do
      @chapter.update!(collects_payout_details: false)
      reminder = PayoutReminder.new(@event)

      assert_equal 1, reminder.recipient_count
      assert reminder.switched_off?
      assert_no_enqueued_emails { assert_not reminder.deliver }
      assert_equal "The Getting paid step is switched off, so caregivers have nowhere to choose.", reminder.refusal
    end

    test "it is not sent once lists are closed" do
      @event.update!(closes_at: 1.hour.ago)
      reminder = PayoutReminder.new(@event)

      assert_no_enqueued_emails { assert_not reminder.deliver }
      assert_equal "Lists are closed, so caregivers can no longer choose for themselves.", reminder.refusal
    end

    test "it is not sent when nobody is waiting or there is no event" do
      @unpaid.household.update!(payout_method: "gift_card", gift_card_email: "denise@example.com")

      assert_equal "No household is waiting on the Getting paid step.", PayoutReminder.new(@event).refusal
      assert_not PayoutReminder.new(nil).deliver
    end

    private

    def enroll(household, event: @event, **attrs)
      Enrollment.create!({ household: household, event: event, submitted_at: Time.current,
                           spending_agreed_at: Time.current }.merge(attrs))
    end
  end
end
