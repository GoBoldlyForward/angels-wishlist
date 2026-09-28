# frozen_string_literal: true

require_relative "intake_test_case"

module Caregiver
  class ListsStepTest < IntakeTestCase
    setup do
      @household, @enrollment = start_household(step: "lists")
      @list = add_child_with_list(@household, first_name: "Amelia", gifts: [])
      sign_in users(:caregiver)
    end

    test "the step opens on the first child's list" do
      get caregiver_intake_lists_path

      assert_redirected_to caregiver_intake_list_path(@list)
      follow_redirect!
      assert_select "h1", "What would Amelia want?"
      assert_select "#capNote", /Lists are capped at \$200 per child. \$200 left on this one./
      assert_select "input[name*=spec], select[name*=catalog]", 0
    end

    test "each child has a chip when there is more than one" do
      other = add_child_with_list(@household, first_name: "Marcus", gifts: [ [ "Basketball", 3_000 ] ])

      get caregiver_intake_list_path(@list)

      assert_select "a.chip.on[href=?]", caregiver_intake_list_path(@list), text: "Amelia · $0"
      assert_select "a.chip[href=?]", caregiver_intake_list_path(other), text: "Marcus · $30"
    end

    test "a gift is added with its price in dollars and a tidied link" do
      assert_difference -> { @list.line_items.count } => 1 do
        post caregiver_intake_list_gifts_path(@list),
             params: { gift: { name: " Skateboard and helmet ", price: "60", link: "example.com/skateboard" } }
      end

      assert_redirected_to caregiver_intake_list_path(@list)
      gift = @list.line_items.sole
      assert_equal [ "Skateboard and helmet", 6_000, "https://example.com/skateboard" ],
                   [ gift.name, gift.price_in_cents, gift.link_url ]

      follow_redirect!
      assert_select ".picked-row", 1
      assert_select ".picked-row .item-link", /example.com/
      assert_select ".total-row b", "$60"
      assert_select "#capNote", /\$140 left on this one/
    end

    test "a typed gift joins the one catalog product it names" do
      item = build_catalog_item(name: "Art supply set")

      post caregiver_intake_list_gifts_path(@list), params: { gift: { name: "art supply set", price: "48" } }

      assert_equal item, @list.line_items.sole.catalog_item
    end

    test "something that is not a link is dropped" do
      post caregiver_intake_list_gifts_path(@list), params: { gift: { name: "Bike", price: "90", link: "the blue one" } }

      assert_nil @list.line_items.sole.link_url
    end

    test "a gift over the cap is refused with the message" do
      build_line_item(wishlist: @list, name: "Bike", price_in_cents: 16_000)

      assert_no_difference -> { LineItem.count } do
        post caregiver_intake_list_gifts_path(@list), params: { gift: { name: "Scooter", price: "45" } }
      end

      assert_response :unprocessable_entity
      assert_select ".field-error", "That price would put this list over the $200 cap. $40 left on it."
      assert_select "input[name=?][value=?]", "gift[name]", "Scooter"
      assert_select ".picked-row", 1
      assert_select ".total-row b", "$160"
    end

    test "a gift under five dollars is refused" do
      assert_no_difference -> { LineItem.count } do
        post caregiver_intake_list_gifts_path(@list), params: { gift: { name: "Stickers", price: "4" } }
      end

      assert_select ".field-error", "That price must be $5 or more."
    end

    test "a list at the cap says so" do
      build_line_item(wishlist: @list, name: "Bike", price_in_cents: 20_000)

      get caregiver_intake_list_path(@list)

      assert_select "#capNote", /This list is at the \$200 cap/
      assert_select "button[disabled]", /Add to the list/
    end

    test "a gift is removed" do
      gift = build_line_item(wishlist: @list)

      assert_difference -> { @list.line_items.count } => -1 do
        delete caregiver_intake_list_gift_path(@list, gift)
      end

      assert_redirected_to caregiver_intake_list_path(@list)
    end

    test "a gift a donor chose stays on the list" do
      gift = build_line_item(wishlist: @list, name: "Bike")
      gift.fund!(build_donation(event: @event))

      assert_no_difference -> { @list.line_items.count } do
        delete caregiver_intake_list_gift_path(@list, gift)
      end

      follow_redirect!
      assert_select ".flash-alert", "A donor already chose Bike, so it stays on the list."
      assert_select ".picked-row", /Chosen by a donor/
      assert_select ".picked-row form", 0
    end

    test "moving on needs a gift on every list" do
      patch finish_caregiver_intake_lists_path

      assert_redirected_to caregiver_intake_list_path(@list)
      assert_equal "Add at least one gift for Amelia.", flash[:alert]
      assert_equal "lists", @enrollment.reload.intake_step
    end

    test "moving on leads to getting paid" do
      build_line_item(wishlist: @list)

      patch finish_caregiver_intake_lists_path

      assert_redirected_to caregiver_intake_payout_path
      assert_equal "payout", @enrollment.reload.intake_step
    end

    test "changing a live list sends it back to review" do
      @list.update!(status: "live")

      post caregiver_intake_list_gifts_path(@list), params: { gift: { name: "Bike", price: "90" } }

      assert @list.reload.in_review?
    end
  end
end
