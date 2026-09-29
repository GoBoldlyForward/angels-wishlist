# frozen_string_literal: true

require_relative "funding_case"

module Admin
  class StripeConnectionTest < FundingCase
    test "in test mode, connecting marks the chapter ready at once" do
      post admin_stripe_connection_path
      assert_redirected_to admin_stripe_connection_url

      follow_redirect!
      assert_redirected_to admin_organization_path(@chapter)
      assert @chapter.reload.stripe_charges_enabled?
      assert_match(/\Aacct_test_/, @chapter.stripe_account_id)
    end

    test "connecting creates the chapter's Express account as a nonprofit that pays out by hand" do
      created = nil
      account_create = ->(params, _options) { created = params; Stripe::Account.construct_from(id: "acct_chapter") }
      link_create = ->(params, _options) { Stripe::AccountLink.construct_from(url: "https://connect.stripe.test/#{params[:account]}") }

      swapping(PaymentGateway, :live?, -> { true }) do
        swapping(Stripe::Account, :create, account_create) do
          swapping(Stripe::AccountLink, :create, link_create) { post admin_stripe_connection_path }
        end
      end

      assert_redirected_to "https://connect.stripe.test/acct_chapter"
      assert_equal "acct_chapter", @chapter.reload.stripe_account_id
      assert_not @chapter.stripe_charges_enabled?
      assert_equal [ "express", "non_profit", "manual" ],
                   [ created[:type], created[:business_type], created.dig(:settings, :payouts, :schedule, :interval) ]
      assert created.dig(:capabilities, :card_payments, :requested)
    end

    test "returning before Stripe has what it needs leaves donations switched off" do
      @chapter.update!(stripe_account_id: "acct_chapter")
      retrieve = ->(_id, _options) { Stripe::Account.construct_from(id: "acct_chapter", charges_enabled: false) }

      swapping(PaymentGateway, :live?, -> { true }) do
        swapping(Stripe::Account, :retrieve, retrieve) { get admin_stripe_connection_path }
      end

      assert_redirected_to admin_organization_path(@chapter)
      assert_equal "Stripe still needs a few details before donations can be taken.", flash[:alert]
      assert_not @chapter.reload.stripe_charges_enabled?
    end

    test "the chapter page offers to connect Stripe until it is connected" do
      get admin_organization_path(@chapter)
      assert_select "form[action=?] button", admin_stripe_connection_path, text: "Connect Stripe"

      @chapter.update!(stripe_account_id: "acct_chapter", stripe_charges_enabled: true)
      get admin_organization_path(@chapter)
      assert_select "form[action=?]", admin_stripe_connection_path, count: 0
      assert_includes response.body, "Can be taken"
    end
  end
end
