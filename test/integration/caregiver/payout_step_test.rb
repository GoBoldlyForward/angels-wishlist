# frozen_string_literal: true

require_relative "intake_test_case"

module Caregiver
  class PayoutStepTest < IntakeTestCase
    setup do
      @household, @enrollment = start_household(step: "payout")
      add_child_with_list(@household)
      sign_in users(:caregiver)
    end

    test "both ways to be paid are offered with the agreement" do
      get caregiver_intake_payout_path

      assert_response :success
      assert_select "input[type=radio][name=?]", "payout[payout_method]", 2
      assert_select ".step-lede", /your household's share/
      assert_select ".step-lede", /#{@event.closes_at.strftime("%B %-d")}/
      assert_select "label.agree", /By accepting these funds, I agree to use them for holiday gifts for the\s+child each list is for\./
      assert_select "label.agree", /I will spend that\s+money on what that child actually needs\./
    end

    test "connecting with Stripe goes to onboarding and comes back connected" do
      post caregiver_intake_stripe_connection_path

      assert_redirected_to caregiver_intake_payout_url
      assert @household.reload.payout_via_stripe?
      assert @household.stripe_connected?

      follow_redirect!
      assert_select ".panel-green", /Connected/
      assert_select "input[type=radio][value=stripe][checked]"
    end

    test "Stripe has to be connected before moving on" do
      patch caregiver_intake_payout_path, params: { payout: { payout_method: "stripe", agreed: "1" } }

      assert_response :unprocessable_entity
      assert_select ".form-errors", /Connect with Stripe first/
      assert @household.reload.payout_via_none?
    end

    test "an account whose Stripe form is unfinished is not connected" do
      @household.update!(payout_method: "stripe", stripe_account_id: "acct_started")

      get caregiver_intake_payout_path
      assert_select ".pay-detail-stripe h3", "Finish connecting with Stripe"
      assert_select ".panel-green", false

      patch caregiver_intake_payout_path, params: { payout: { payout_method: "stripe", agreed: "1" } }
      assert_response :unprocessable_entity
      assert_select ".form-errors", /Finish connecting with Stripe/
    end

    test "coming back from Stripe with the form finished marks the account connected" do
      @household.update!(payout_method: "stripe", stripe_account_id: "acct_started")

      with_live_stripe_account(details_submitted: true) { get caregiver_intake_payout_path }

      assert @household.reload.stripe_connected?
      assert_select ".panel-green", /Connected/
    end

    test "coming back from Stripe without finishing leaves the account unconnected" do
      @household.update!(payout_method: "stripe", stripe_account_id: "acct_started")

      with_live_stripe_account(details_submitted: false) { get caregiver_intake_payout_path }

      assert_not @household.reload.stripe_connected?
      assert_select ".pay-detail-stripe h3", "Finish connecting with Stripe"
    end

    test "choosing Stripe once connected records the method and the agreement" do
      @household.update!(stripe_account_id: "acct_test_1", stripe_onboarded_at: Time.current)

      patch caregiver_intake_payout_path, params: { payout: { payout_method: "stripe", agreed: "1" } }

      assert_redirected_to caregiver_intake_review_path
      assert @household.reload.payout_via_stripe?
      assert @enrollment.reload.spending_agreed?
      assert_equal "review", @enrollment.intake_step
    end

    test "a gift card is mailed to the address given" do
      patch caregiver_intake_payout_path, params: { payout: {
        payout_method: "gift_card", agreed: "1", street_line_1: "88 Magnolia Court", city: "Jonesboro", zipcode: "30236"
      } }

      assert_redirected_to caregiver_intake_review_path
      assert @household.reload.payout_via_gift_card?
      assert_equal "88 Magnolia Court, Jonesboro, GA 30236", @household.mailing_address.to_s
    end

    test "a gift card needs somewhere to go" do
      patch caregiver_intake_payout_path, params: { payout: { payout_method: "gift_card", agreed: "1" } }

      assert_response :unprocessable_entity
      assert_select ".field-error", "Mailing address can't be blank."
      assert @household.reload.payout_via_none?
    end

    test "the agreement has to be checked" do
      @household.update!(stripe_account_id: "acct_test_1", stripe_onboarded_at: Time.current)

      patch caregiver_intake_payout_path, params: { payout: { payout_method: "stripe", agreed: "0" } }

      assert_response :unprocessable_entity
      assert_select ".form-errors", /Check the box to agree/
      assert_not @enrollment.reload.spending_agreed?
    end

    test "a method has to be chosen" do
      patch caregiver_intake_payout_path, params: { payout: { agreed: "1" } }

      assert_response :unprocessable_entity
      assert_select ".form-errors", /Payout method has to be chosen/
    end

    private

    def with_live_stripe_account(details_submitted:)
      original_live = PaymentGateway.method(:live?)
      original_retrieve = Stripe::Account.method(:retrieve)
      PaymentGateway.define_singleton_method(:live?) { true }
      Stripe::Account.define_singleton_method(:retrieve) { |*| Struct.new(:details_submitted).new(details_submitted) }
      yield
    ensure
      PaymentGateway.define_singleton_method(:live?, original_live)
      Stripe::Account.define_singleton_method(:retrieve, original_retrieve)
    end
  end
end
