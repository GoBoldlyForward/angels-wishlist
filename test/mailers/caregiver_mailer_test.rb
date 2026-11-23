# frozen_string_literal: true

require "test_helper"

class CaregiverMailerTest < ActionMailer::TestCase
  test "the payout reminder says what is missing, where to give it, and by when" do
    chapter = build_organization(name: "Nashville Angels", mail_from: "Nashville Angels <wishlist@nashvilleangels.example>")
    event = build_event(organization: chapter, name: "Christmas 2026", closes_at: Time.zone.local(2026, 12, 8, 12))
    household = build_household(organization: chapter, payout_method: "none", stripe_account_id: nil)
    enrollment = Enrollment.create!(household: household, event: event, submitted_at: Time.current)

    mail = CaregiverMailer.payout_needed(enrollment)
    body = mail.body.to_s

    assert_equal [ household.caregiver.email ], mail.to
    assert_equal [ "wishlist@nashvilleangels.example" ], mail.from
    assert_equal "Tell us how to send your household's share", mail.subject
    assert_match(/We have your lists for Christmas 2026\./, body)
    assert_match(/^- Choose how you would like to be paid\.$/, body)
    assert_match(/^- Agree to how the funds will be spent\.$/, body)
    assert_includes body, "http://example.com/caregiver/intake/payout"
    assert_match(/before lists close on December 08, 2026\./, body)
  end

  test "the payout reminder names only what a half-connected household still owes" do
    household = build_household(stripe_account_id: "acct_started", stripe_onboarded_at: nil)
    enrollment = Enrollment.create!(household: household, event: build_event(organization: household.organization),
                                    submitted_at: Time.current, spending_agreed_at: Time.current)

    body = CaregiverMailer.payout_needed(enrollment).body.to_s

    assert_match(/^- Finish connecting with Stripe\.$/, body)
    assert_no_match(/Choose how you would like to be paid/, body)
    assert_no_match(/Agree to how the funds/, body)
  end
end
