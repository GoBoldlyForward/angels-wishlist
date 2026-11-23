# frozen_string_literal: true

require "test_helper"
require_relative "storefront_program"

module Public
  class HeardAboutTest < ActionDispatch::IntegrationTest
    include StorefrontProgram

    setup do
      build_storefront
      @donation = build_donation(event: @event)
    end

    test "the thank-you page asks how the donor heard about us, and one click saves the answer" do
      visit donation_path(uuid: @donation.uuid)
      assert_select ".heard-about h2", "How did you hear about us?"
      assert_select ".heard-about button[name=?]", "donation[heard_about]", Donation::HEARD_ABOUT_CHOICES.size

      answer heard_about: "News or TV (like Good Day Atlanta)"

      assert_redirected_to donation_path(uuid: @donation.uuid)
      assert_equal "News or TV (like Good Day Atlanta)", @donation.reload.heard_about
      follow_redirect!
      assert_select ".heard-about", /Thank you for telling us how you found us/
      assert_select ".heard-about button", 0
    end

    test "something else is saved with the donor's own words" do
      visit donation_path(uuid: @donation.uuid)
      assert_select ".heard-about input[name=?][maxlength='100'][required]", "donation[heard_about_other]"

      answer heard_about_other: "  A flyer at   the Kroger on Holcomb Bridge "

      assert_equal "Something else: A flyer at the Kroger on Holcomb Bridge", @donation.reload.heard_about
    end

    test "an answer that is not one of the choices is turned away and the question asked again" do
      answer heard_about: "A billboard"

      assert_redirected_to donation_path(uuid: @donation.uuid)
      assert_nil @donation.reload.heard_about
      follow_redirect!
      assert_select ".flash-alert", /Pick one of the answers below/
      assert_select ".heard-about h2", "How did you hear about us?"
    end

    test "the question waits until the payment has gone through" do
      pending = build_donation(event: @event, status: "pending")

      visit donation_path(uuid: pending.uuid)
      assert_select "h1", "We are confirming your payment."
      assert_select ".heard-about", 0

      answer pending, heard_about: "Passion"
      assert_response :not_found
      assert_nil pending.reload.heard_about
    end

    private

    def answer(donation = @donation, **fields)
      patch donation_path(uuid: donation.uuid), params: { donation: fields }, headers: BROWSER
    end
  end
end
