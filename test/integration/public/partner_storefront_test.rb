# frozen_string_literal: true

require "test_helper"
require_relative "storefront_program"

module Public
  class PartnerStorefrontTest < ActionDispatch::IntegrationTest
    include StorefrontProgram
    include ActionMailer::TestHelper

    PARTNER = "passion-city-church"
    PREFIX = "/with/#{PARTNER}"

    setup do
      build_storefront
      @mayas_hoodie = ask(@maya, @hoodie, days_ago: 9)
      @theos_hoodie = ask(@theo, @hoodie, days_ago: 7, spec: "Nike, size L")
      @scooter = ask(@theo, nil, days_ago: 3, name: "Purple scooter")
    end

    test "every page renders in the partner's skin and keeps its links inside" do
      add_to_cart @mayas_hoodie, storefront: PARTNER

      pages = [ PREFIX, "#{PREFIX}?tab=children", "#{PREFIX}?tab=unfunded", "#{PREFIX}?tab=give",
                "#{PREFIX}?gender=girl", "#{PREFIX}/categories/clothes-shoes", "#{PREFIX}/gifts/hoodie",
                "#{PREFIX}/gifts/#{@theo.slug}--purple-scooter", "#{PREFIX}/children/#{@maya.slug}",
                "#{PREFIX}/cart", "#{PREFIX}/checkout" ]

      pages.each do |page|
        visit page

        assert_response :success, "#{page} did not render"
        assert_select "link[rel=stylesheet][href*=?]", "theme-passion", { count: 1 }, "#{page} lost the partner's theme"
        assert_select ".brand-name", /Passion City Church/
        assert_empty links_leaving_the_storefront, "#{page} links out of the partner's storefront"
      end
    end

    test "the chapter's own storefront has no partner prefix" do
      visit root_path

      assert_select "link[rel=stylesheet][href*=?]", "theme-angels"
      assert_select "a[href^=?]", "/with/", count: 0
      assert_select "form[action^=?]", "/with/", count: 0
    end

    test "a partner's visitor adds, checks out, and lands on a confirmation inside the storefront" do
      post gift_funding_path(storefront: PARTNER, gift_id: "hoodie"), params: { quantity: 1 }, headers: BROWSER
      assert_redirected_to "#{PREFIX}/gifts/hoodie"

      post category_funding_path(storefront: PARTNER, category_id: "clothes-shoes"),
           params: { whole_category: 1 }, headers: BROWSER
      assert_redirected_to "#{PREFIX}/categories/clothes-shoes"

      post child_funding_path(storefront: PARTNER, child_id: @theo.slug), headers: BROWSER
      post cart_general_gifts_path(storefront: PARTNER), params: { amount: 50 }, headers: BROWSER
      assert_redirected_to "#{PREFIX}?tab=give#shop"

      assert_enqueued_emails 1 do
        check_out storefront: PARTNER
      end

      donation = Donation.last
      assert_redirected_to "http://www.example.com#{PREFIX}/donations/#{donation.uuid}"
      assert_equal @partner, donation.storefront_organization
      assert_equal 11_500, donation.gift_in_cents
      assert_equal 5_000, donation.general_gift_in_cents
      assert_equal 3, donation.line_items.count

      follow_redirect!

      assert_response :success
      assert_select "link[rel=stylesheet][href*=?]", "theme-passion"
      assert_select "h1", /You gave \$165/
      assert_empty links_leaving_the_storefront
    end

    test "a checkout that fails validation stays in the partner's skin" do
      add_to_cart @mayas_hoodie, storefront: PARTNER

      check_out storefront: PARTNER, email: ""

      assert_response :unprocessable_content
      assert_select "link[rel=stylesheet][href*=?]", "theme-passion"
      assert_select "form[action=?]", "#{PREFIX}/checkout"
    end

    test "an unknown or inactive partner falls back to the chapter" do
      @partner.update!(active: false)

      visit PREFIX

      assert_response :success
      assert_select "link[rel=stylesheet][href*=?]", "theme-angels"
    end

    private

    # Links and forms that point at this site but outside /with/<partner>. The caregiver
    # side belongs to the chapter, so its link is expected to leave.
    def links_leaving_the_storefront
      targets = css_select("a[href]").map { |link| link["href"] } + css_select("form[action]").map { |form| form["action"] }
      targets.select { |target| target.start_with?("/") }
             .reject { |target| target.start_with?(PREFIX, "/caregiver", "/assets", "/rails/active_storage") }
    end
  end
end
