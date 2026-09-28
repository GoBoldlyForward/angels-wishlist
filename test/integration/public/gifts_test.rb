# frozen_string_literal: true

require "test_helper"
require_relative "storefront_program"

module Public
  class GiftsTest < ActionDispatch::IntegrationTest
    include StorefrontProgram

    setup do
      build_storefront
      @mayas_hoodie = ask(@maya, @hoodie, days_ago: 9)
      @mayas_art = ask(@maya, @art_set, days_ago: 8)
      @theos_hoodie = ask(@theo, @hoodie, days_ago: 7, spec: "Nike, size L", link_url: "https://www.example.com/hoodie")
      @nova = build_listed_child(build_private_household, "Nova", age: 6, gender: "girl")
      @novas_hoodie = ask(@nova, @hoodie, days_ago: 5)
    end

    test "a product shows the pool and each specific request" do
      visit gift_path(id: "hoodie")

      assert_response :success
      assert_select "h1", "Hoodie"
      assert_select ".kid-meta", /3 still needed of 3 asked for/
      assert_select ".pool-panel h2", "Fund one for any child who asked"
      assert_select ".pool-panel p", /Waiting: Maya, 9 · Nova, 6\./
      assert_select ".pool-panel p", /We apply each one to the child who has been waiting longest/
      assert_select ".pool-panel input[name=quantity][max=?]", "2"
      assert_select ".mini", text: /Nike, size L/ do
        assert_select "a.item-link[href=?]", "https://www.example.com/hoodie", text: /example\.com/
        assert_select "form[action=?]", cart_gifts_path
      end
    end

    test "a product page is also a dialog when a frame asks for it" do
      get gift_path(id: "hoodie"), headers: BROWSER.merge("Turbo-Frame" => "modal")

      assert_response :success
      assert_select "turbo-frame#modal h1", "Hoodie"
      assert_select "header.hdr", 0
    end

    test "adding pooled gifts takes the oldest open lines" do
      older = ask(build_listed_child(build_private_household, "Iris", age: 8, gender: "girl"), @hoodie, days_ago: 30)

      post gift_funding_path(gift_id: "hoodie"), params: { quantity: 2 }, headers: BROWSER

      assert_redirected_to gift_path(id: "hoodie")
      assert_equal [ older.id, @mayas_hoodie.id ], session[:cart]["line_item_ids"]
    end

    test "adding pooled gifts skips lines already in the cart and never takes a specific request" do
      add_to_cart @mayas_hoodie

      post gift_funding_path(gift_id: "hoodie"), params: { quantity: 5 }, headers: BROWSER

      assert_equal [ @mayas_hoodie.id, @novas_hoodie.id ], session[:cart]["line_item_ids"]
    end

    test "gifts in this visitor's cart stop counting as needed for them" do
      add_to_cart @mayas_hoodie

      visit gift_path(id: "hoodie")

      assert_select ".pool-panel input[name=quantity][max=?]", "1"
      assert_select ".pool-panel p", /Waiting: Nova, 6\./
      assert_select ".carted-panel", /1 in your cart for Maya/

      visit root_path(tab: "unfunded")

      assert_select "a.tile[href=?] .need-tag", gift_path(id: "hoodie"), text: "2 needed"
    end

    test "gifts can be taken back out from the product" do
      add_to_cart @mayas_hoodie
      add_to_cart @mayas_art

      delete gift_funding_path(gift_id: "hoodie"), headers: BROWSER

      assert_equal [ @mayas_art.id ], session[:cart]["line_item_ids"]
    end

    test "a funded line cannot be added" do
      @mayas_hoodie.fund!(build_donation(event: @event, gift_in_cents: 4_000))

      add_to_cart @mayas_hoodie

      assert_empty session[:cart].to_h.fetch("line_item_ids", [])
      follow_redirect!
      assert_select ".flash-alert", /no longer open/
    end

    test "a line that is withdrawn, in review, or on a hidden list cannot be added" do
      withdrawn = ask(@maya, @art_set, days_ago: 2, status: "withdrawn")
      waiting = ask(@maya, @art_set, days_ago: 2, status: "needs_review")
      hidden = ask(build_listed_child(build_household(organization: @chapter, verification_status: "hold",
                                                      hold_reason: "Placement change"),
                                      "Wren", age: 7, gender: "girl"), @hoodie, days_ago: 40)

      [ withdrawn, waiting, hidden ].each { |line| add_to_cart line }
      post gift_funding_path(gift_id: "hoodie"), params: { quantity: 1 }, headers: BROWSER

      assert_equal [ @mayas_hoodie.id ], session[:cart]["line_item_ids"]
    end

    test "a forged gift key adds nothing" do
      post cart_gifts_path, params: { gift: @mayas_hoodie.id.to_s }, headers: BROWSER

      assert_nil session[:cart]
    end

    test "a child's page shows what a donor may know and nothing else" do
      @mayas_art.fund!(build_donation(event: @event, gift_in_cents: 2_000, display_name: "The Reyes family"))

      visit child_path(id: @maya.slug)

      assert_response :success
      assert_select "h1", "Maya, 9"
      assert_select ".kid-meta", "Girl · DeKalb County"
      assert_select ".detail-tags .tag", 4
      assert_select ".caregiver-note", /She draws on every page she can find/
      assert_select ".fund-line", /\$20\s+of \$60 chosen/
      assert_select ".mini.is-funded", text: /Art supply set\s+Chosen by The Reyes family/
      assert_select "form[action=?] button", child_funding_path(child_id: @maya.slug),
                    text: "Fund the rest of Maya's list · $40"
    end

    test "an anonymous gift shows as Anonymous on the child's page" do
      donor = build_donor(first_name: "Priya", last_name: "Sundaram")
      @mayas_art.fund!(build_donation(event: @event, donor: donor, gift_in_cents: 2_000,
                                      anonymous: true, display_name: nil))

      visit child_path(id: @maya.slug)

      assert_select ".mini.is-funded", text: /Chosen by Anonymous/
      assert_no_match(/Priya|Sundaram|#{Regexp.escape(donor.email)}/, response.body)
    end

    test "funding the rest of a list adds every open line on it" do
      @mayas_art.fund!(build_donation(event: @event, gift_in_cents: 2_000))
      extra = ask(@maya, @art_set, days_ago: 1, name: "Sketchbook", price_in_cents: 1_200)

      post child_funding_path(child_id: @maya.slug), headers: BROWSER

      assert_equal [ @mayas_hoodie.id, extra.id ], session[:cart]["line_item_ids"]
    end

    test "a category page counts what is open and lists the other categories" do
      visit category_path(id: "clothes-shoes")

      assert_response :success
      assert_select "h1", "The clothes they actually need this winter"
      assert_select ".cat-lede", /3 gifts in this category are still\s+unfunded, asked for by 3 children across\s+2 verified households/
      assert_select ".cat-cta button", /Add\s+2\s+to cart/
      assert_select ".cat-cta button", "Cover the whole category · $120"
      assert_select ".grid a.tile", 1
      assert_select ".other-categories a.chip[href=?]", category_path(id: "art-music"), text: /Art & Music\s*1/
    end

    test "category filters narrow the grid" do
      visit category_path(id: "clothes-shoes", age: "13-18")

      assert_select ".grid a.tile .tile-for", /For Theo, 14/

      visit category_path(id: "clothes-shoes", price: "100+")

      assert_select ".grid a.tile", 0
      assert_select ".grid p", "Nothing matches these filters."
    end

    test "giving a few gifts from a category takes its oldest open lines" do
      post category_funding_path(category_id: "clothes-shoes"), params: { quantity: 2 }, headers: BROWSER

      assert_equal [ @mayas_hoodie.id, @theos_hoodie.id ], session[:cart]["line_item_ids"]
    end

    test "covering the whole category adds every open line in it" do
      add_to_cart @theos_hoodie

      post category_funding_path(category_id: "clothes-shoes"), params: { whole_category: 1 }, headers: BROWSER

      assert_equal [ @theos_hoodie.id, @mayas_hoodie.id, @novas_hoodie.id ], session[:cart]["line_item_ids"]
      assert_not_includes session[:cart]["line_item_ids"], @mayas_art.id
    end
  end
end
