# frozen_string_literal: true

require_relative "funding_case"

module Admin
  class PayoutsTest < FundingCase
    setup do
      @brooks, = build_list(asking: [ 20_000 ], display_name: "The Brooks home")
      @okafor, = build_list(asking: [ 10_000, 3_333 ], display_name: "The Okafor home", payout_method: "gift_card",
                            stripe_account_id: nil, gift_card_email: "okafor@example.com")
      @pending, = build_list(asking: [ 15_000 ], display_name: "The Pending home", verification_status: "pending")
      @no_method, = build_list(asking: [ 7_001 ], display_name: "The Nowhere home", payout_method: "none",
                               stripe_account_id: nil)
      build_donation(event: @event, gift_in_cents: 0, general_gift_in_cents: 25_001)
    end

    test "the index shows the run before it is built" do
      get admin_payouts_path

      assert_response :success
      assert_select "tbody tr", 3
      assert_select "td", text: /The Brooks home/
      assert_select "td", text: /The Pending home/, count: 0
      assert_select "td", text: /not built yet/, count: 3
      assert_select "td", text: /No payout method on file/
      assert_select ".stat-card", text: /\$250\.01/
      assert_select ".alert-success", text: /3 payouts add up to \$250\.01.*The pool is \$250\.01.*match to the cent/m
      assert_select ".alert-success", text: /Nothing is built yet/
      assert_equal 0, Payout.count
    end

    test "building payouts creates one per household and the amounts add up to the pool" do
      assert_difference -> { Payout.count }, 3 do
        post build_admin_payouts_path
      end

      assert_redirected_to admin_payouts_path
      assert_equal [ @brooks.id, @no_method.id, @okafor.id ].sort, @event.payouts.pluck(:household_id).sort
      assert_equal 25_001, @event.payouts.sum(:amount_in_cents)
      assert_equal @event.raised_in_cents, @event.payouts.sum(:amount_in_cents)

      follow_redirect!
      assert_select ".alert-success", text: /match to the cent/
      assert_select "td", text: /not built yet/, count: 0
    end

    test "building again keeps one payout per household and leaves a sent one alone" do
      post build_admin_payouts_path
      sent = @event.payouts.find_by(household: @brooks)
      patch send_funds_admin_payout_path(sent)
      build_donation(event: @event, gift_in_cents: 0, general_gift_in_cents: 5_000)

      assert_no_difference -> { Payout.count } do
        post build_admin_payouts_path
      end

      assert_no_changes -> { sent.reload.amount_in_cents } do
        post build_admin_payouts_path
      end
      assert sent.sent?
    end

    test "the index says so when the payouts no longer add up to the pool" do
      post build_admin_payouts_path
      build_donation(event: @event, gift_in_cents: 0, general_gift_in_cents: 5_000)

      get admin_payouts_path

      assert_select ".alert-warning", text: /\$50\.00 short of the pool/
      assert_select ".alert-warning", text: /Build payouts again/
    end

    test "tabs, search, and filters narrow the run" do
      post build_admin_payouts_path

      get admin_payouts_path(tab: "blocked")
      assert_select "tbody tr", 1
      assert_select "td", text: /The Nowhere home/

      get admin_payouts_path(q: "okafor")
      assert_select "tbody tr", 1

      get admin_payouts_path(f: { method: "gift_card" })
      assert_select "tbody tr", 1
      assert_select "td", text: /Emailed gift card/
      assert_select "td", text: "okafor@example.com"
    end

    test "the index exports to CSV" do
      post build_admin_payouts_path
      get admin_payouts_path(format: :csv)

      assert_response :success
      assert_equal "text/csv", response.media_type
      assert_equal 3, csv_rows.size
      brooks = csv_rows.find { |row| row["Household"] == "The Brooks home" }
      assert_equal "200", brooks["Asked"]
      assert_equal "scheduled", brooks["Status"]
      assert_equal 25_001, csv_rows.sum { |row| (BigDecimal(row["Payout"]) * 100).to_i }
    end

    test "sending a Stripe payout in test mode marks it sent and tells the caregiver" do
      post build_admin_payouts_path
      payout = @event.payouts.find_by(household: @brooks)

      assert_enqueued_emails 1 do
        patch send_funds_admin_payout_path(payout)
      end

      assert_redirected_to admin_payout_path(payout)
      assert payout.reload.sent?
      assert_match(/\Atr_test_/, payout.stripe_transfer_id)
      assert payout.sent_at.present?
    end

    test "a gift card payout is recorded as ordered in Tremendous, with the order ID when staff have it" do
      post build_admin_payouts_path
      payout = @event.payouts.find_by(household: @okafor)
      assert_equal "okafor@example.com", payout.gift_card_email

      get admin_payout_path(payout)
      assert_select "p", /Order a \$[\d.,]+ gift card in Tremendous for okafor@example\.com/
      assert_select "input[name=?][required]", "payout[gift_card_order_id]", count: 0

      assert_enqueued_emails 1 do
        patch send_funds_admin_payout_path(payout), params: { payout: { gift_card_order_id: " ORD-7F3K " } }
      end
      assert payout.reload.sent?
      assert_equal "ORD-7F3K", payout.gift_card_order_id

      email = CaregiverMailer.payout_sent(payout)
      assert_match(/sent as a gift card to okafor@example\.com/, email.body.to_s)
      assert_match(/email from Tremendous/, email.body.to_s)
      assert_no_match(/mailed|tracking/, email.body.to_s)
    end

    test "a gift card household with no email for it is blocked" do
      @okafor.update!(gift_card_email: nil)
      post build_admin_payouts_path
      payout = @event.payouts.find_by(household: @okafor)

      assert payout.blocked?
      assert_equal "No email address for the gift card.", payout.blocker
    end

    test "a blocked payout cannot be sent and says why" do
      post build_admin_payouts_path
      payout = @event.payouts.find_by(household: @no_method)

      assert_no_enqueued_emails do
        patch send_funds_admin_payout_path(payout)
      end

      assert payout.reload.blocked?
      assert_equal "No payout method on file.", flash[:alert]

      get admin_payout_path(payout)
      assert_select ".alert-warning", text: /No payout method on file/
      assert_select "form[action=?]", send_funds_admin_payout_path(payout), count: 0
    end

    test "a household placed on hold after the build cannot be sent" do
      post build_admin_payouts_path
      payout = @event.payouts.find_by(household: @brooks)
      @brooks.hold!("Placement changed.")

      patch send_funds_admin_payout_path(payout)

      assert payout.reload.scheduled?
      assert_equal "Placement changed.", flash[:alert]
    end

    test "a payout built before the pool changed is not sent until it is rebuilt" do
      post build_admin_payouts_path
      payout = @event.payouts.find_by(household: @brooks)
      build_donation(event: @event, gift_in_cents: 0, general_gift_in_cents: 5_000)

      patch send_funds_admin_payout_path(payout)

      assert payout.reload.scheduled?
      assert_match(/pool has changed/, flash[:alert])
    end

    test "a failed transfer shows its reason and can be sent again" do
      post build_admin_payouts_path
      payout = @event.payouts.find_by(household: @brooks)
      payout.mark_failed!("The account is restricted.")

      get admin_payout_path(payout)
      assert_select ".alert-danger", text: /The account is restricted/
      assert_select "form[action=?] button", send_funds_admin_payout_path(payout), text: /Send again/

      patch send_funds_admin_payout_path(payout)
      assert payout.reload.sent?
      assert_nil payout.hold_reason
    end

    test "a sent payout can be marked delivered, and only a sent one" do
      post build_admin_payouts_path
      payout = @event.payouts.find_by(household: @brooks)

      patch mark_delivered_admin_payout_path(payout)
      assert payout.reload.scheduled?

      patch send_funds_admin_payout_path(payout)
      patch mark_delivered_admin_payout_path(payout)
      assert payout.reload.delivered?

      patch send_funds_admin_payout_path(payout)
      assert_equal "This payout has already been sent.", flash[:alert]
    end

    test "there is no way to set the amount by hand" do
      post build_admin_payouts_path
      payout = @event.payouts.find_by(household: @brooks)

      assert_no_changes -> { payout.reload.amount_in_cents } do
        patch send_funds_admin_payout_path(payout), params: { payout: { amount_in_cents: 1 } }
      end
    end
  end
end
