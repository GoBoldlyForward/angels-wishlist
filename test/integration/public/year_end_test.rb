# frozen_string_literal: true

require "test_helper"
require_relative "storefront_program"

module Public
  class YearEndTest < ActionDispatch::IntegrationTest
    include StorefrontProgram

    setup { build_storefront }

    test "the year-end page offers the appeal and the tiers with nothing to shop" do
      visit year_end_path

      assert_response :success
      assert_select "h1", "The lists are for December. Atlanta Angels is there all year."
      assert_select ".yeg-stat b", "163"
      assert_select "input[type=radio][name=amount]", 8
      assert_select "button", text: "Continue"
      assert_select ".cart-btn", 0
      assert_select ".tile", 0
      assert_select "#other-ways .yeg-way", text: /payable to Atlanta Angels and mail it to 2555 Northwinds Pkwy/
      assert_select "#other-ways a[href=?]", "https://www.every.org/atlantaangels#/donate/card"
      assert_select "#other-ways", text: /EIN 85-2051575/
    end

    test "a chapter that blanked its mailing address shows only the link" do
      @chapter.update!(year_end_appeal: { "check_address" => "" })

      visit year_end_path

      assert_select "#other-ways .yeg-way", 1
      assert_select "#other-ways .yeg-way", text: /Stock, crypto, donor-advised fund, or wire/
    end

    test "choosing a gift there leads straight to giving" do
      post cart_year_end_gift_path, params: { amount: "custom", custom_amount: "75" }, headers: BROWSER
      assert_redirected_to checkout_path

      visit year_end_path
      assert_select ".yeg-chosen", /\$75 year-end gift/
      assert_select ".yeg-chosen a[href=?]", checkout_path, text: "Give now"
      assert_select "input[name=custom_amount][value='75']"
    end

    test "a chapter that has switched the appeal off has no page" do
      @chapter.update!(year_end_appeal: { "enabled" => false })

      visit year_end_path

      assert_redirected_to root_path
    end

    test "a partner's storefront has its own year-end page" do
      visit year_end_path(storefront: @partner.slug)

      assert_response :success
      assert_select "form[action=?]", cart_year_end_gift_path(storefront: @partner.slug)
    end
  end
end
