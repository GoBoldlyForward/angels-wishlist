# frozen_string_literal: true

require "test_helper"
require_relative "storefront_program"

module Public
  class CartTest < ActionDispatch::IntegrationTest
    include StorefrontProgram

    setup do
      build_storefront
      @mayas_hoodie = ask(@maya, @hoodie, days_ago: 9)
      @theos_hoodie = ask(@theo, @hoodie, days_ago: 7, spec: "Nike, size L")
    end

    test "the header counts what is in the cart on every page" do
      visit root_path
      assert_select "a.cart-btn[href=?] .cart-count", cart_path, text: "0"

      add_to_cart @mayas_hoodie
      post cart_general_gifts_path, params: { amount: 25 }, headers: BROWSER

      visit category_path(id: "clothes-shoes")
      assert_select "a.cart-btn .cart-count", "2"
    end

    test "the cart lists each gift and each general gift with a total" do
      add_to_cart @mayas_hoodie
      add_to_cart @theos_hoodie
      post cart_general_gifts_path, params: { amount: "50" }, headers: BROWSER

      visit cart_path

      assert_response :success
      assert_select "main .line", 3
      assert_select "main .line", text: /Hoodie\s+For Maya, 9/
      assert_select "main .line", text: /Hoodie\s+Nike, size L · For Theo, 14/
      assert_select "main .line", text: /General gift/
      assert_select "main .total-row b", "$130"
      assert_select "main a[href=?]", checkout_path, text: "Review and give"
      assert_select "aside.drawer[role=dialog][hidden] .line", 3
    end

    test "the drawer opens once, on the page shown right after something is added" do
      post cart_gifts_path, params: { gift: gift_key(@mayas_hoodie) },
                            headers: BROWSER.merge("Referer" => root_url(tab: "unfunded"))
      assert_redirected_to root_url(tab: "unfunded")
      follow_redirect!
      assert_select "body[data-cart-drawer-open-value=true]"
      assert_select ".flash-notice", "1 gift added to your cart."

      visit root_path
      assert_select "body[data-cart-drawer-open-value=false]"
    end

    test "a gift can be removed" do
      add_to_cart @mayas_hoodie
      add_to_cart @theos_hoodie

      delete cart_gift_path(id: gift_key(@mayas_hoodie)), headers: BROWSER

      assert_redirected_to cart_path
      assert_equal [ @theos_hoodie.id ], session[:cart]["line_item_ids"]
    end

    test "a general gift can be removed" do
      post cart_general_gifts_path, params: { amount: 25 }, headers: BROWSER
      post cart_general_gifts_path, params: { amount: 100 }, headers: BROWSER

      delete cart_general_gift_path(id: 0), headers: BROWSER

      assert_equal [ 10_000 ], session[:cart]["general_gifts"]
    end

    test "a general gift has to be five dollars or more" do
      [ "4", "0", "-20", "abc", "" ].each do |amount|
        post cart_general_gifts_path, params: { amount: amount }, headers: BROWSER
      end

      assert_nil session[:cart]
      follow_redirect!
      assert_select ".flash-alert", /\$5 or more/

      post cart_general_gifts_path, params: { amount: "5" }, headers: BROWSER
      assert_equal [ 500 ], session[:cart]["general_gifts"]
    end

    test "a gift somebody else funded leaves the cart with a short notice" do
      add_to_cart @mayas_hoodie
      add_to_cart @theos_hoodie
      @mayas_hoodie.fund!(build_donation(event: @event, gift_in_cents: 4_000))

      visit cart_path

      assert_select ".flash-notice", "A gift in your cart is no longer open, so we took it out."
      assert_select "main .line", 1
      assert_equal [ @theos_hoodie.id ], session[:cart]["line_item_ids"]

      visit cart_path
      assert_select ".flash-notice", 0
    end

    test "a gift whose list was withdrawn leaves the cart" do
      add_to_cart @theos_hoodie
      @theo.withdraw!

      visit root_path

      assert_select ".flash-notice", /no longer open/
      assert_select "a.cart-btn .cart-count", "0"
    end

    test "adding to the cart is never a GET" do
      get "/cart/gifts", params: { gift: gift_key(@mayas_hoodie) }, headers: BROWSER

      assert_response :not_found
      assert_nil session[:cart]
    end
  end
end
