# frozen_string_literal: true

require_relative "families_test_case"

module Admin
  class InboxTest < FamiliesTestCase
    setup do
      @household, @wishlist = build_family
      @art = build_line_item(wishlist: @wishlist, name: "Art supply set")
      @pending, @waiting = build_family(name: "The Sinclair home", alias_name: "Ruby", list_status: "in_review",
                                        verification_status: "pending")
      enroll(@pending)
      @pricey = build_line_item(wishlist: @wishlist, name: "Weighted blanket", price_in_cents: 6_000,
                                status: "needs_review")
      @donation = build_donation(event: @event, display_name: "Priya S.",
                                 note_to_family: "We picked the art set because our daughter draws too.")
      @art.fund!(@donation)
    end

    test "the inbox shows the four queues with their actions" do
      get admin_inbox_path

      assert_response :success
      assert_select "#households .item-name", text: "The Sinclair home"
      assert_select "#households form[action=?]", verify_admin_household_path(@pending)
      assert_select "#wishlists .item-name", text: "Ruby, 9"
      assert_select "#wishlists a[href=?]", admin_household_path(@pending), text: "Verify the household first"
      assert_select "#wishlists form[action=?]", approve_admin_wishlist_path(@waiting), count: 0
      assert_select "#line-items .item-name", text: "Weighted blanket"
      assert_select "#line-items form[action=?]", approve_admin_line_item_path(@pricey)
      assert_select "#donor-notes .drawer-quote", text: "We picked the art set because our daughter draws too."
      assert_select "#donor-notes .item-name", text: "Priya S."
      assert_select "#donor-notes a[href=?]", admin_household_path(@household), text: "The Brooks home"
    end

    test "a list whose household is verified can be approved from the inbox" do
      @pending.verify!

      get admin_inbox_path

      assert_select "#households .item-name", count: 0
      assert_select "#wishlists form[action=?]", approve_admin_wishlist_path(@waiting)
    end

    test "an empty inbox says so" do
      @pending.verify!
      @waiting.approve!
      @pricey.approve!
      @donation.approve_note!

      get admin_inbox_path

      assert_response :success
      assert_select "#households td", text: "No household is waiting to be verified."
      assert_select "#donor-notes td", text: "No donor note is waiting."
    end

    test "approving a donor note records who did it" do
      patch approve_admin_donor_note_path(@donation)

      assert_redirected_to admin_inbox_path
      assert_not_nil @donation.reload.note_approved_at
      assert_not @donation.note_pending_review?
      assert_equal @staff, @donation.versions.reorder(:id).last.actor

      follow_redirect!
      assert_select "#donor-notes .drawer-quote", count: 0
    end

    test "discarding a donor note removes it" do
      patch discard_admin_donor_note_path(@donation)

      assert_redirected_to admin_inbox_path
      assert_nil @donation.reload.note_to_family
      assert_nil @donation.note_approved_at
    end

    test "a note on another event's donation is not found" do
      elsewhere = build_donation(event: build_event(organization: @chapter, opened_at: 1.year.ago, closes_at: 11.months.ago),
                                 note_to_family: "Thinking of you.")

      patch approve_admin_donor_note_path(elsewhere)

      assert_response :not_found
      assert_nil elsewhere.reload.note_approved_at
    end
  end
end
