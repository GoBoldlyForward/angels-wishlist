require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "an organizer reaches only the chapters they belong to, in name order" do
    nashville = build_organization(name: "Nashville Angels")
    atlanta = build_organization(name: "Atlanta Angels")
    organizer = build_organizer(organization: nashville)
    OrganizationMembership.create!(user: organizer, organization: atlanta)
    build_organization(name: "Birmingham Angels")

    assert_equal [ atlanta, nashville ], organizer.available_organizations.to_a
  end

  test "an admin reaches every organization that hosts a drive without a membership" do
    chapter = build_organization
    partner = build_organization(kind: "partner", parent: chapter)
    agency = build_organization(kind: "agency", parent: chapter)
    admin = build_admin

    assert admin.organization_memberships.none?
    assert admin.organizes?(chapter)
    assert admin.organizes?(partner)
    assert_not admin.organizes?(agency)
  end

  test "a caregiver and a donor organize nothing" do
    build_organization

    assert_not build_caregiver.organizes_anything?
    assert_not build_donor.organizes_anything?
  end

  test "a membership to an agency never counts as reach" do
    organizer = build_organizer
    agency = build_organization(kind: "agency")

    assert_not organizer.organizes?(agency)
  end

  test "a donor row from checkout needs no password until they set one" do
    donor = User.new(email: "guest@example.com", role: "donor")

    assert donor.valid?
    assert_not User.new(email: "cg@example.com", role: "caregiver", first_name: "A", last_name: "B").valid?
  end
end
