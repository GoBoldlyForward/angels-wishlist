require "test_helper"
class SmokeTest < ActionDispatch::IntegrationTest
  test "public root renders" do
    get root_path
    assert_response :success
  end
  test "household root redirects when signed out" do
    get household_root_path
    assert_response :redirect
  end
  test "admin root redirects when signed out" do
    get admin_root_path
    assert_response :redirect
  end
end
