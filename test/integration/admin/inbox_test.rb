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
      assert_select "#donor-notes form[action=?] textarea", admin_donor_note_path(@donation),
                    text: "We picked the art set because our daughter draws too."
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

    test "discarding a donor note removes it and keeps its wording in the audit trail" do
      patch discard_admin_donor_note_path(@donation)

      assert_redirected_to admin_inbox_path
      assert_nil @donation.reload.note_to_family
      assert_nil @donation.note_approved_at
      assert_recorded_by_staff @donation, "note_to_family", [ "We picked the art set because our daughter draws too.", nil ]
    end

    test "editing a donor note keeps it waiting and keeps the donor's wording in the audit trail" do
      patch admin_donor_note_path(@donation), params: { donor_note: { note_to_family: " We picked the art set for her. " } }

      assert_redirected_to admin_inbox_path
      assert_equal "We picked the art set for her.", @donation.reload.note_to_family
      assert @donation.note_pending_review?
      assert_recorded_by_staff @donation, "note_to_family",
                               [ "We picked the art set because our daughter draws too.", "We picked the art set for her." ]
    end

    test "a note cannot be edited down to nothing" do
      patch admin_donor_note_path(@donation), params: { donor_note: { note_to_family: "   " } }

      assert_equal "Note to family can't be blank", flash[:alert]
      assert_equal "We picked the art set because our daughter draws too.", @donation.reload.note_to_family
    end

    test "an approved note can no longer be edited" do
      @donation.approve_note!

      patch admin_donor_note_path(@donation), params: { donor_note: { note_to_family: "Something else." } }

      assert_equal "Only a note waiting for approval can be edited.", flash[:alert]
      assert_equal "We picked the art set because our daughter draws too.", @donation.reload.note_to_family
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
