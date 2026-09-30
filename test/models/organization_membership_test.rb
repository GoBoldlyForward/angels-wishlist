require "test_helper"

class OrganizationMembershipTest < ActiveSupport::TestCase
  test "an organizer joins a chapter through a membership" do
    organizer = build_organizer

    assert organizer.organizations.one?
    assert organizer.organizes?(organizer.organizations.first)
  end

  test "a donor cannot be given a membership" do
    membership = OrganizationMembership.new(user: build_donor, organization: build_organization)

    assert_not membership.valid?
    assert_includes membership.errors[:user], "must be an organizer"
  end

  test "an agency cannot have members" do
    membership = OrganizationMembership.new(user: build_organizer, organization: build_organization(kind: "agency"))

    assert_not membership.valid?
    assert_includes membership.errors[:organization], "must be a chapter or a partner"
  end

  test "the same pair is refused while live and allowed again after it is revoked" do
    organizer = build_organizer
    organization = organizer.organizations.first

    assert_not OrganizationMembership.new(user: organizer, organization: organization).valid?

    organizer.organization_memberships.first.destroy
    assert OrganizationMembership.create!(user: organizer, organization: organization).persisted?
  end

  test "revoking a membership takes the chapter out of reach" do
    organizer = build_organizer
    organization = organizer.organizations.first

    organizer.organization_memberships.first.destroy

    assert_not organizer.reload.organizes?(organization)
    assert_not organizer.organizes_anything?
  end
end
