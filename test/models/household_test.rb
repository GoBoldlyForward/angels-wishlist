# frozen_string_literal: true

require "test_helper"

class HouseholdTest < ActiveSupport::TestCase
  test "verifying a household records who verified it and what changed" do
    household = build_household(verification_status: "pending")
    staff = users(:staff)

    PaperTrail.request(whodunnit: staff.id) do
      household.update!(verification_status: "verified", verified_at: Time.current)
    end

    version = household.versions.last
    assert_equal "update", version.event
    assert_equal staff, version.actor
    assert_equal [ "pending", "verified" ], version.changeset["verification_status"]
    assert_equal "pending", version.reify.verification_status
  end

  test "putting a household on hold records the reason" do
    household = build_household

    PaperTrail.request(whodunnit: users(:staff).id) do
      household.update!(verification_status: "hold", hold_reason: "Placement change reported.")
    end

    assert_equal [ nil, "Placement change reported." ], household.versions.last.changeset["hold_reason"]
  end

  test "a change outside the audited columns writes no version" do
    household = build_household

    assert_no_difference -> { household.versions.count } do
      household.update!(county: "Fulton County")
    end
  end
end
