# frozen_string_literal: true

require_relative "intake_test_case"

module Caregiver
  class DashboardTest < IntakeTestCase
    setup do
      @household, @enrollment = start_household(step: "review")
      @list = add_child_with_list(@household, first_name: "Amelia",
                                              gifts: [ [ "Skateboard and helmet", 6_000 ], [ "Art supply set", 4_000 ] ])
      make_ready(@household, @enrollment)
      @enrollment.submit!
      sign_in users(:caregiver)
    end

    test "a submitted caregiver sees their lists, household, payout, Love Box, and dates" do
      get caregiver_root_path

      assert_response :success
      assert_select ".brand img[src*=?]", "chapters/atlanta-angels"
      assert_select "h1", "Your lists for #{@event.name}"
      assert_select "#list-#{@list.id} .status-in_review", "In review"
      assert_select "#list-#{@list.id} .gift-row", 2
      assert_select ".status-pending", "Being confirmed"
      assert_select ".review-side", /Bank account or debit card, through Stripe/
      assert_select ".fund-line", /Lists close\s*#{@event.closes_at.strftime("%B %-d")}/
      assert_select ".fund-line", /Your share is sent\s*#{@event.payout_at.strftime("%B %-d")}/
      assert_select ".fund-line", /Holiday celebrated\s*Christmas/
      assert_select "a[href=?]", caregiver_intake_list_path(@list), text: "Edit list"
      assert_select ".flow-step", 3
    end

    test "a live list shows what donors have chosen" do
      @list.approve!
      @household.verify!
      @list.line_items.order(:id).first.fund!(build_donation(event: @event))

      get caregiver_root_path

      assert_select "#list-#{@list.id} .status-live", "Live"
      assert_select "#list-#{@list.id} .status-chosen", 1
      assert_select "#list-#{@list.id} .fund-line", /Donors have chosen \$60\s*\$100 asked/
      assert_select ".status-verified", "Verified"
    end

    test "a hold is shown without the staff's reason" do
      @household.hold!("Placement ended in October.")

      get caregiver_root_path

      assert_select ".status-hold", "On hold"
      assert_no_match(/Placement ended/, response.body)
    end

    test "steps saved after submitting come back to the dashboard" do
      patch caregiver_intake_love_box_path, params: { love_box: full_love_box.merge("drink" => { picks: [ "Apple cider" ] }) }

      assert_redirected_to caregiver_root_path
      assert_equal [ "Apple cider" ], @enrollment.reload.love_box.dig("drink", "picks")
    end

    test "nothing can be edited once the event closes" do
      @event.update!(opened_at: 2.months.ago, closes_at: 1.day.ago)

      get caregiver_root_path
      assert_response :success
      assert_select "a", text: "Edit list", count: 0
      assert_select "a", text: "Edit box", count: 0

      post caregiver_intake_list_gifts_path(@list), params: { gift: { name: "Bike", price: "20" } }
      assert_redirected_to caregiver_root_path
      assert_equal 2, @list.line_items.count
    end

    test "approved notes from the donors who chose this household's gifts show, newest first" do
      skateboard, art = @list.line_items.order(:id).to_a
      give(skateboard, display_name: "The Hollis family", note_to_family: "Merry Christmas, Amelia!", created_at: 1.day.ago)
      give(art, display_name: nil, anonymous: true, note_to_family: "Thinking of you all.")

      get caregiver_root_path

      assert_select "#donor-notes blockquote", 2
      assert_select "#donor-notes blockquote", text: "“Merry Christmas, Amelia!”"
      assert_equal [ "From Anonymous", "From The Hollis family" ], css_select("#donor-notes figcaption").map(&:text)
    end

    test "a note still waiting on staff does not show" do
      give(@list.line_items.first, note_to_family: "Merry Christmas, Amelia!", approved: false)

      get caregiver_root_path

      assert_select "#donor-notes", count: 0
    end

    test "a note for another household's gifts does not show" do
      elsewhere = build_wishlist(child: build_child(household: build_household(organization: @chapter)), event: @event)
      give(build_line_item(wishlist: elsewhere), note_to_family: "Merry Christmas!")

      get caregiver_root_path

      assert_select "#donor-notes", count: 0
    end

    test "a general gift's note does not show" do
      build_donation(event: @event, gift_in_cents: 0, general_gift_in_cents: 5_000,
                     note_to_family: "Merry Christmas!").approve_note!

      get caregiver_root_path

      assert_select "#donor-notes", count: 0
    end

    test "refunding a gift takes its note off the dashboard" do
      donation = give(@list.line_items.first, note_to_family: "Merry Christmas, Amelia!")
      get caregiver_root_path
      assert_select "#donor-notes blockquote", 1

      donation.refund!
      get caregiver_root_path

      assert_select "#donor-notes", count: 0
    end

    private

    def give(line, approved: true, **attrs)
      donation = build_donation(event: @event, **attrs)
      line.fund!(donation)
      donation.approve_note! if approved
      donation
    end
  end
end
