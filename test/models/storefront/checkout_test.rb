# frozen_string_literal: true

require "test_helper"

module Storefront
  class CheckoutTest < ActiveSupport::TestCase
    setup do
      @event = build_event
      @wishlist = build_wishlist(child: build_child(household: build_household(organization: @event.organization)),
                                 event: @event)
      @line = build_line_item(wishlist: @wishlist, price_in_cents: 4_800)
      @session = {}
      @cart = Cart.new(@session, event: @event)
      @cart.add_gift(@line.signed_id(purpose: Gift::KEY_PURPOSE))
    end

    test "it makes one pending donation and empties the cart" do
      @cart.add_general_gift(2_000)
      checkout = build(email: "kate.hollis@example.com", display_name: "The Hollis family",
                       note_to_family: "Thinking of you.")

      assert_difference -> { Donation.count } => 1, -> { User.count } => 1 do
        assert checkout.save
      end

      donation = checkout.donation
      assert donation.pending?
      assert_equal [ 4_800, 2_000, 204 ], [ donation.gift_in_cents, donation.general_gift_in_cents, donation.fee_in_cents ]
      assert_equal({ "line_item_ids" => [ @line.id ] }, donation.cart)
      assert_equal "Thinking of you.", donation.note_to_family
      assert_equal @event.organization, donation.storefront_organization
      assert_not @line.reload.funded?
      assert_empty @session
    end

    test "the fee is on unless the donor turns it off" do
      assert_equal 144, build(email: "kate.hollis@example.com").fee_in_cents
      assert_equal 0, build(email: "kate.hollis@example.com", cover_fee: "0").fee_in_cents
      assert_equal 4_800, build(email: "kate.hollis@example.com", cover_fee: "0").charged_in_cents
    end

    test "an email is required" do
      checkout = build(email: " ")

      assert_not checkout.save
      assert_includes checkout.errors[:email].first, "required"
      assert_nil checkout.donation
    end

    test "a new donor has no password and the donor role" do
      checkout = build(email: "New.Donor@Example.com")
      checkout.save

      donor = checkout.donation.donor
      assert_equal "new.donor@example.com", donor.email
      assert donor.donor?
      assert_predicate donor.encrypted_password, :blank?
    end

    test "an empty cart cannot be checked out" do
      @cart.clear

      checkout = build(email: "kate.hollis@example.com")

      assert_not checkout.save
      assert_includes checkout.errors[:base], "Your cart is empty."
    end

    test "a gift funded since it was added stops the checkout before any charge" do
      @cart.add_general_gift(2_000)
      @line.fund!(build_donation(event: @event))

      checkout = build(email: "kate.hollis@example.com")

      assert_no_difference -> { Donation.count } do
        assert_not checkout.save
      end
      assert_match(/chosen by someone else first/, checkout.errors[:base].first)
      assert_equal 2_000, @cart.total_in_cents
    end

    test "the donation is recorded as the donor's own act" do
      checkout = build(email: "kate.hollis@example.com")

      PaperTrail.request(whodunnit: nil) { checkout.save }

      assert_equal checkout.donation.donor, checkout.donation.versions.last.actor
    end

    private

    def build(**attributes)
      Checkout.new(attributes, cart: @cart, event: @event, storefront: @event.organization)
    end
  end
end
