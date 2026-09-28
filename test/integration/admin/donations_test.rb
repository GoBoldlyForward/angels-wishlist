# frozen_string_literal: true

require_relative "funding_case"

module Admin
  class DonationsTest < FundingCase
    setup do
      _household, @wishlist, (@bike, @helmet) = build_list(asking: [ 12_000, 3_000 ])
      @donor = build_donor(first_name: "Priya", last_name: "Sundaram")
      @mixed = build_donation(event: @event, donor: @donor, gift_in_cents: 12_000, general_gift_in_cents: 2_500,
                              fee_in_cents: 435, stripe_payment_intent_id: "pi_mixed", payment_method_label: "Card",
                              note_to_family: "Thinking of you.")
      @bike.fund!(@mixed)
      @general = build_donation(event: @event, donor: build_donor(first_name: "Dev", last_name: "Raghunathan"),
                                gift_in_cents: 0, general_gift_in_cents: 5_000, anonymous: true,
                                stripe_payment_intent_id: "pi_general", payment_method_label: "Card")
      @pending = build_donation(event: @event, donor: build_donor(first_name: "Sandra", last_name: "Coyle"),
                                gift_in_cents: 3_000, status: "pending", stripe_payment_intent_id: "pi_pending")
    end

    test "the index shows both parts of a mixed donation" do
      get admin_donations_path

      assert_response :success
      assert_select "tbody tr", 3
      assert_select "td", text: /1 gift for #{@wishlist.child.display_name}/
      assert_select "td", text: /Where it is needed most/, count: 2
      assert_select "td", text: /#{@mixed.uuid.first(8)}/
      assert_select "td", text: "$149.35"
    end

    test "tabs narrow the ledger and carry counts" do
      get admin_donations_path(tab: "pending")
      assert_select "tbody tr", 1
      assert_select "td", text: /#{@pending.uuid.first(8)}/

      get admin_donations_path(tab: "general")
      assert_select "tbody tr", 2

      get admin_donations_path(tab: "offline")
      assert_select ".empty-state"
    end

    test "search finds a donation by reference or donor" do
      get admin_donations_path(q: @general.uuid.first(8))
      assert_select "tbody tr", 1

      get admin_donations_path(q: "sundaram")
      assert_select "tbody tr", 1
    end

    test "the index exports to CSV" do
      get admin_donations_path(format: :csv)

      assert_response :success
      assert_equal "text/csv", response.media_type
      mixed = csv_rows.find { |row| row["Reference"] == @mixed.uuid.first(8) }
      assert_equal "149.35", mixed["Charged"]
      assert_equal "1 gift for #{@wishlist.child.display_name} + Where it is needed most", mixed["What they chose"]
    end

    test "the donation page shows the charge, the donor, and the note awaiting approval" do
      get admin_donation_path(@mixed)

      assert_response :success
      assert_select ".drawer-section h4", text: "The charge"
      assert_select ".drawer-section h4", text: "What this is"
      assert_select ".drawer-quote", text: "Thinking of you."
      assert_select ".status-badge", text: /Awaiting approval/
      assert_select "td", text: /Art supply set/
    end

    test "refunding takes the donation out of the pool and returns its gifts to open" do
      assert_changes -> { @event.reload.raised_in_cents }, from: 19_500, to: 5_000 do
        patch refund_admin_donation_path(@mixed)
      end

      assert_redirected_to admin_donation_path(@mixed)
      assert @mixed.reload.refunded?
      assert_not @bike.reload.funded?
      assert @bike.open_status?
    end

    test "a donation that has not succeeded cannot be refunded" do
      patch refund_admin_donation_path(@pending)

      assert_redirected_to admin_donation_path(@pending)
      assert @pending.reload.pending?
      assert_match(/Only a succeeded donation/, flash[:alert])
    end

    test "resending a receipt enqueues one email" do
      assert_enqueued_emails 1 do
        post resend_receipt_admin_donation_path(@mixed)
      end
      assert_redirected_to admin_donation_path(@mixed)
    end

    test "recording an offline gift adds to the pool" do
      assert_difference -> { @event.reload.raised_in_cents }, 25_000 do
        post admin_donations_path, params: { offline_gift: {
          donor_name: "Grady nurses fund", email: "Nurses@Grady.example.org", amount_in_dollars: "250",
          given_on: 3.days.ago.to_date, payment_method_label: "Check", display_name: "", anonymous: "0"
        } }
      end

      donation = Donation.order(:id).last
      assert_redirected_to admin_donation_path(donation)
      assert donation.succeeded?
      assert donation.offline?
      assert_equal [ 0, 25_000, 0 ], [ donation.gift_in_cents, donation.general_gift_in_cents, donation.fee_in_cents ]
      assert_equal "Check", donation.payment_method_label
      assert_equal 3.days.ago.to_date, donation.created_at.to_date
      assert_equal "Grady nurses fund", donation.display_name
      assert donation.donor.donor?
      assert_equal "nurses@grady.example.org", donation.donor.email

      get admin_donations_path(tab: "offline")
      assert_select "tbody tr", 1
    end

    test "an offline gift from a known email reuses that donor" do
      assert_no_difference -> { User.count } do
        post admin_donations_path, params: { offline_gift: {
          donor_name: "Priya Sundaram", email: @donor.email, amount_in_dollars: "40.50",
          given_on: Date.current, payment_method_label: "Cash", anonymous: "1"
        } }
      end

      donation = @donor.donations.order(:id).last
      assert_equal 4_050, donation.general_gift_in_cents
      assert donation.anonymous?
    end

    test "an offline gift under five dollars is refused" do
      assert_no_difference -> { Donation.count } do
        post admin_donations_path, params: { offline_gift: {
          donor_name: "Sam Low", email: "sam.low@example.com", amount_in_dollars: "4",
          given_on: Date.current, payment_method_label: "Cash"
        } }
      end

      assert_response :unprocessable_entity
      assert_select ".alert-danger", text: /\$5 or more/
    end
  end
end
