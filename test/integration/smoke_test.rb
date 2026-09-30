require "test_helper"

class SmokeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "public root renders" do
    get root_path
    assert_response :success
  end

  test "sign in renders" do
    get new_user_session_path
    assert_response :success
  end

  test "caregiver root renders or redirects when signed out" do
    get caregiver_root_path
    assert_includes [ 200, 302 ], response.status
  end

  test "admin root redirects when signed out" do
    get admin_root_path
    assert_redirected_to new_user_session_path
  end

  test "an organizer reaches their chapter and nothing else" do
    organizer = build_organizer
    sign_in organizer

    get admin_root_path
    assert_response :success
    assert_includes response.body, organizer.organizations.first.name

    get caregiver_root_path
    assert_redirected_to root_path
  end

  test "an admin reaches every chapter" do
    chapter = build_organization(name: "Atlanta Angels")
    sign_in build_admin

    get admin_root_path
    assert_response :success
    assert_includes response.body, chapter.name
  end

  test "an organizer with no chapter left is turned away from the staff area" do
    organizer = build_organizer
    organizer.organization_memberships.destroy_all
    sign_in organizer

    get admin_root_path
    assert_redirected_to root_path
  end

  test "a partner's organizer has no staff pages" do
    chapter = build_organization(name: "Atlanta Angels")
    sign_in build_organizer(organization: build_organization(name: "Passion City", kind: "partner", parent: chapter))

    get admin_root_path
    assert_redirected_to root_path
  end

  test "switching chapters changes the chapter the staff area works in" do
    first = build_organization(name: "Atlanta Angels")
    second = build_organization(name: "Nashville Angels")
    organizer = build_organizer(organization: first)
    OrganizationMembership.create!(user: organizer, organization: second)
    sign_in organizer

    get admin_root_path
    assert_select ".breadcrumb-item a", text: "Atlanta Angels"

    patch current_organization_path, params: { organization_id: second.id }
    follow_redirect!
    assert_select ".breadcrumb-item a", text: "Nashville Angels"
  end

  test "a chapter outside an organizer's memberships cannot be switched to" do
    organizer = build_organizer
    elsewhere = build_organization(name: "Nashville Angels")
    sign_in organizer

    patch current_organization_path, params: { organization_id: elsewhere.id }
    assert_redirected_to root_path

    get admin_root_path
    assert_select ".breadcrumb-item a", text: organizer.organizations.first.name
  end
end
