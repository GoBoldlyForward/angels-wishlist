# frozen_string_literal: true

require "test_helper"

class DonationTest < ActiveSupport::TestCase
  test "charged is the gift plus general giving plus the fee" do
    donation = build_donation(event: build_event, gift_in_cents: 4_800,
                              general_gift_in_cents: 2_000, fee_in_cents: 204)

    assert_equal 7_004, donation.charged_in_cents
  end

  test "covering the fee is the presence of a fee" do
    assert build_donation(event: build_event, fee_in_cents: 144).fee_covered?
    assert_not build_donation(event: build_event, fee_in_cents: 0).fee_covered?
  end

  test "a donation carrying no money at all is rejected" do
    donation = Donation.new(donor: build_donor, event: build_event,
                            gift_in_cents: 0, general_gift_in_cents: 0)

    assert_not donation.valid?
    assert_includes donation.errors[:base].first, "gift or a general amount"
  end

  test "an anonymous gift still records the donor behind it" do
    donation = build_donation(event: build_event, anonymous: true, display_name: "Priya S.")

    assert_equal "Anonymous", donation.public_display_name
    assert_not_nil donation.donor.email
  end

  test "a note to the family waits on staff before it is forwarded" do
    donation = build_donation(event: build_event, note_to_family: "Could you send a photo?")

    assert donation.note_pending_review?
    assert_includes Donation.with_unapproved_note, donation

    donation.approve_note!
    assert_not donation.reload.note_pending_review?
  end

  test "a donation is addressed by uuid rather than its id" do
    assert_equal 36, build_donation(event: build_event).to_param.length
  end
  test "approving a note records who approved it" do
    donation = build_donation(event: build_event, note_to_family: "Could you send a photo?")
    staff = users(:staff)

    PaperTrail.request(whodunnit: staff.id) { donation.approve_note! }

    before, after = donation.versions.last.changeset["note_approved_at"]
    assert_equal staff, donation.versions.last.actor
    assert_nil before
    assert_not_nil after
  end
end
