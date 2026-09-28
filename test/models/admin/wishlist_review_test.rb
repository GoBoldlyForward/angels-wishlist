# frozen_string_literal: true

require "test_helper"

module Admin
  class WishlistReviewTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

    setup do
      @household = build_household
      @event = build_event(organization: @household.organization)
      @wishlist = build_wishlist(child: build_child(household: @household), event: @event, status: "in_review")
    end

    test "approving also opens the lines that were waiting on a price" do
      line = build_line_item(wishlist: @wishlist, status: "needs_review")

      assert WishlistReview.new(@wishlist).approve
      assert @wishlist.reload.live?
      assert line.reload.open_status?
    end

    test "a withdrawn sibling does not hold back the email that the lists are live" do
      build_wishlist(child: build_child(household: @household), event: @event, status: "withdrawn")

      assert_enqueued_email_with CaregiverMailer, :lists_live, args: [ @household, @event ] do
        WishlistReview.new(@wishlist).approve
      end
    end

    test "a household on hold blocks approval" do
      @household.hold!("Placement change reported.")
      review = WishlistReview.new(@wishlist.reload)

      assert_not review.approve
      assert_match(/has to be verified/, review.error)
      assert @wishlist.reload.in_review?
    end

    test "only a list in review can be approved" do
      @wishlist.update!(status: "draft")
      review = WishlistReview.new(@wishlist)

      assert_not review.approve
      assert_equal "Only a list in review can be approved.", review.error
    end

    test "a live list can be returned, and the caregiver is sent the reason" do
      @wishlist.update!(status: "live", approved_at: Time.current)

      assert_enqueued_email_with CaregiverMailer, :list_returned, args: [ @wishlist ] do
        assert WishlistReview.new(@wishlist).return_to_caregiver("  The note names a school. ")
      end

      assert @wishlist.reload.draft?
      assert_nil @wishlist.approved_at
      assert_equal "The note names a school.", @wishlist.review_note
    end

    test "a draft cannot be returned and a withdrawn list cannot be withdrawn again" do
      @wishlist.update!(status: "draft")
      assert_not WishlistReview.new(@wishlist).return_to_caregiver("Anything.")

      @wishlist.update!(status: "withdrawn")
      assert_not WishlistReview.new(@wishlist).withdraw
    end
  end
end
