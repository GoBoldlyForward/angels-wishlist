# frozen_string_literal: true

require "test_helper"
require_relative "storefront_program"

module Public
  class CheckoutTest < ActionDispatch::IntegrationTest
    include StorefrontProgram
    include ActionMailer::TestHelper

    setup do
      build_storefront
      @mayas_hoodie = ask(@maya, @hoodie, days_ago: 9)
      @theos_hoodie = ask(@theo, @hoodie, days_ago: 7, spec: "Nike, size L")
    end

    test "checkout with an empty cart goes back to the cart" do
      visit checkout_path

      assert_redirected_to cart_path
    end

    test "checkout groups chosen gifts by child and asks for an email, a name, a note, and the fee" do
      add_to_cart @mayas_hoodie
      add_to_cart @theos_hoodie
      post cart_general_gifts_path, params: { amount: 25 }, headers: BROWSER

      visit checkout_path

      assert_response :success
      assert_select ".checkout-group h2", "Maya, 9"
      assert_select ".checkout-group h2", "Theo, 14"
      assert_select ".checkout-group h2", "General gift"
      assert_select "input[type=email][name=?][required]", "checkout[email]"
      assert_select "label[for=checkout_display_name]", "Your name, as it should appear"
      assert_select "textarea[name=?][maxlength=?]", "checkout[note_to_family]", "1000"
      assert_select "input[type=checkbox][name=?][checked]", "checkout[cover_fee]"
      assert_select ".fee-choice", /Add \$3\.15 to cover card processing, so the full \$105\s+goes to the program/
      assert_select ".total-row b", "$108.15"
      assert_select "form[action=?][data-turbo=false]", checkout_path
    end

    test "a note is offered only when the cart holds a chosen gift" do
      post cart_general_gifts_path, params: { amount: 25 }, headers: BROWSER

      visit checkout_path
      assert_select "textarea", 0

      check_out note_to_family: "Thinking of you."
      assert_nil Donation.last.note_to_family
    end

    test "checkout requires an email" do
      add_to_cart @mayas_hoodie

      assert_no_difference -> { Donation.count }, -> { User.count } do
        check_out email: ""
      end

      assert_response :unprocessable_content
      assert_select ".field-error", /Email is required/
      assert_equal [ @mayas_hoodie.id ], session[:cart]["line_item_ids"]
      assert_not @mayas_hoodie.reload.funded?
    end

    test "checkout turns away an email that cannot receive a receipt" do
      add_to_cart @mayas_hoodie

      assert_no_difference -> { Donation.count } do
        check_out email: "not-an-email"
      end

      assert_response :unprocessable_content
      assert_select ".field-error", /Email/
    end

    test "gifts for two children and a general gift make one donation and one receipt" do
      add_to_cart @mayas_hoodie
      add_to_cart @theos_hoodie
      post cart_general_gifts_path, params: { amount: 25 }, headers: BROWSER

      assert_difference -> { Donation.count } => 1, -> { User.donor.count } => 1 do
        assert_enqueued_emails 1 do
          check_out note_to_family: "Thinking of you all this Christmas."
        end
      end

      donation = Donation.last
      assert_redirected_to donation_url(uuid: donation.uuid)
      assert donation.succeeded?
      assert_equal 8_000, donation.gift_in_cents
      assert_equal 2_500, donation.general_gift_in_cents
      assert_equal 315, donation.fee_in_cents
      assert_equal 10_815, donation.charged_in_cents
      assert_equal "kate.hollis@example.com", donation.donor.email
      assert donation.donor.donor?
      assert_equal "The Hollis family", donation.display_name
      assert_not donation.anonymous?
      assert_equal @chapter, donation.storefront_organization
      assert_equal @event, donation.event
      assert_equal [ @mayas_hoodie.id, @theos_hoodie.id ], donation.cart["line_item_ids"]
      assert_equal donation, @mayas_hoodie.reload.donation
      assert_equal donation, @theos_hoodie.reload.donation
      assert donation.note_pending_review?
      assert_nil session[:cart]
    end

    test "the fee changes what is charged and never the gift" do
      add_to_cart @mayas_hoodie
      check_out cover_fee: "0"
      without_fee = Donation.last

      add_to_cart @theos_hoodie
      check_out cover_fee: "1"
      with_fee = Donation.last

      assert_equal [ 4_000, 0, 4_000 ], [ without_fee.gift_in_cents, without_fee.fee_in_cents, without_fee.charged_in_cents ]
      assert_equal [ 4_000, 120, 4_120 ], [ with_fee.gift_in_cents, with_fee.fee_in_cents, with_fee.charged_in_cents ]
      assert_equal 8_000, @event.reload.raised_in_cents
    end

    test "a blank name makes the gift anonymous" do
      add_to_cart @mayas_hoodie

      check_out display_name: "  "

      donation = Donation.last
      assert donation.anonymous?
      assert_nil donation.display_name
      assert_equal "kate.hollis@example.com", donation.donor.email

      visit child_path(id: @maya.slug)
      assert_select ".mini.is-funded", text: /Chosen by Anonymous/
    end

    test "a returning donor's gifts share one user" do
      add_to_cart @mayas_hoodie
      check_out email: "Kate.Hollis@Example.com "
      add_to_cart @theos_hoodie

      assert_no_difference -> { User.count } do
        check_out email: "kate.hollis@example.com"
      end

      assert_equal 2, User.find_by(email: "kate.hollis@example.com").donations.count
    end

    test "an email that belongs to a caregiver or staff uses that user" do
      add_to_cart @mayas_hoodie

      assert_no_difference -> { User.count } do
        check_out email: users(:admin).email
      end

      assert_equal users(:admin), Donation.last.donor
      assert users(:admin).reload.admin?
    end

    test "a note longer than a thousand characters is turned away" do
      add_to_cart @mayas_hoodie

      assert_no_difference -> { Donation.count } do
        check_out note_to_family: "a" * 1_001
      end

      assert_response :unprocessable_content
      assert_select ".field-error", /Note/
    end

    test "a donor is told before being charged when a gift was funded first" do
      add_to_cart @mayas_hoodie
      add_to_cart @theos_hoodie
      @mayas_hoodie.fund!(build_donation(event: @event, gift_in_cents: 4_000))

      assert_no_difference -> { Donation.count } do
        assert_no_enqueued_emails { check_out }
      end

      assert_response :unprocessable_content
      assert_select ".flash-alert", /chosen by someone else first/
      assert_select ".checkout-group h2", text: "Maya, 9", count: 0
      assert_select ".total-row b", "$41.20"
    end

    test "the confirmation names the amount, the gifts, the note, and what happens next" do
      add_to_cart @mayas_hoodie
      post cart_general_gifts_path, params: { amount: 25 }, headers: BROWSER
      check_out note_to_family: "Thinking of you all this Christmas."
      follow_redirect!

      assert_response :success
      assert_select "h1", /You gave \$65/
      assert_select ".confirmation-head", /charged \$66\.95/
      assert_select ".mini", text: /Hoodie\s+For Maya, 9/
      assert_select ".mini", text: /General gift/
      assert_select ".confirmation-note", /Thinking of you all this Christmas/
      assert_select ".confirmation-note", /held until Atlanta Angels has read it/
      assert_select ".confirmation-next", /#{@event.closes_at.strftime("%B %-d")}/
      assert_select ".confirmation-next", /pooled and spread evenly across every child's list/
      assert_select ".confirmation-next", /a thank-you and an impact statement from Atlanta Angels in January/
      assert_no_match(/\/donations\/\d+/, response.body)
    end

    test "a gift funded by someone else first is shown as going into the pool" do
      donation = build_donation(event: @event, status: "pending", gift_in_cents: 8_000,
                                cart: { "line_item_ids" => [ @mayas_hoodie.id, @theos_hoodie.id ] })
      @mayas_hoodie.fund!(build_donation(event: @event, gift_in_cents: 4_000))
      donation.settle!

      visit donation_path(uuid: donation.uuid)

      assert_select "h1", /You gave \$80/
      assert_select ".mini", text: /Hoodie\s+Nike, size L · For Theo, 14/
      assert_select ".mini", text: /Someone else chose this gift for Maya just before you, so this amount went\s+into the pool as a general gift/
    end

    test "a pending donation says the payment is being confirmed" do
      donation = build_donation(event: @event, status: "pending", gift_in_cents: 4_000,
                                cart: { "line_item_ids" => [ @mayas_hoodie.id ] })

      visit donation_path(uuid: donation.uuid)

      assert_response :success
      assert_select "h1", "We are confirming your payment."
      assert_select ".mini", text: /Hoodie\s+For Maya, 9/
    end

    test "a donation is reached by its uuid and nothing else" do
      donation = build_donation(event: @event)

      visit donation_path(uuid: donation.id)
      assert_response :not_found

      visit donation_path(uuid: "not-a-uuid")
      assert_response :not_found
    end

    test "a live checkout is refused while the chapter's Stripe account is not connected" do
      add_to_cart @mayas_hoodie

      with_live_gateway(->(*) { flunk "Stripe was asked to charge" }) do
        assert_no_difference(-> { Donation.count }) { check_out }
      end

      assert_response :unprocessable_content
      assert_includes response.body, "Atlanta Angels is not taking card donations yet"
    end

    test "a live checkout sends the donor to Stripe and leaves the receipt to the gateway" do
      @chapter.update!(stripe_charges_enabled: true)
      add_to_cart @mayas_hoodie
      asked = nil
      start = lambda do |donation, success_url:, cancel_url:|
        asked = { donation: donation, success_url: success_url, cancel_url: cancel_url }
        PaymentGateway::Checkout.new(url: "https://checkout.stripe.test/pay/cs_test_1", reference: "cs_test_1")
      end

      with_live_gateway(start) do
        assert_no_enqueued_emails { check_out }
      end

      donation = Donation.last
      assert_redirected_to "https://checkout.stripe.test/pay/cs_test_1"
      assert donation.pending?
      assert_not @mayas_hoodie.reload.funded?
      assert_equal "#{donation_url(uuid: donation.uuid)}?session_id={CHECKOUT_SESSION_ID}", asked[:success_url]
      assert_equal donation_url(uuid: donation.uuid), asked[:cancel_url]
      assert_nil session[:cart]
    end

    private

    def with_live_gateway(start)
      original_live = PaymentGateway.method(:live?)
      original_start = PaymentGateway.method(:start_checkout)
      PaymentGateway.define_singleton_method(:live?) { true }
      PaymentGateway.define_singleton_method(:start_checkout, &start)
      yield
    ensure
      PaymentGateway.define_singleton_method(:live?, original_live)
      PaymentGateway.define_singleton_method(:start_checkout, original_start)
    end
  end
end
