require "test_helper"

class SmokeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "public root renders" do
    get root_path
    assert_response :success
  end

  test "caregiver root renders or redirects when signed out" do
    get caregiver_root_path
    assert_includes [ 200, 302 ], response.status
  end

  test "admin root redirects when signed out" do
    get admin_root_path
    assert_response :redirect
  end

  test "admin root renders for staff" do
    sign_in users(:staff)
    get admin_root_path
    assert_response :success
  end

  test "sign in renders" do
    get new_user_session_path
    assert_response :success
  end
end
