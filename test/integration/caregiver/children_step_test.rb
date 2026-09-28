# frozen_string_literal: true

require_relative "intake_test_case"

module Caregiver
  class ChildrenStepTest < IntakeTestCase
    setup do
      @household, @enrollment = start_household(step: "children")
      sign_in users(:caregiver)
    end

    test "the first visit offers one blank child with a stand-in name already assigned" do
      get caregiver_intake_children_path

      assert_response :success
      assert_select ".child-form", 1
      assert_select ".child-form .hint b", Child::ALIASES.first
      assert_select "input[name$='[display_name]'][value=?]", Child::ALIASES.first
    end

    test "saving creates each child, an alias, and a draft list with the interests and the note" do
      assert_difference -> { @household.children.count } => 2, -> { Wishlist.count } => 2 do
        patch caregiver_intake_children_path, params: { children: {
          "n1" => child_fields(legal_first_name: "Amelia", interests: [ "Drawing", " drawing ", "soccer" ],
                               caregiver_note: "Draws on every napkin in the house."),
          "n2" => child_fields(legal_first_name: "Marcus", gender: "boy", birthdate: 12.years.ago.to_date)
        } }
      end

      assert_redirected_to caregiver_intake_love_box_path
      amelia, marcus = @household.children.order(:id).to_a
      assert_equal Child::ALIASES.first(2), [ amelia.display_name, marcus.display_name ]
      assert_equal 12, marcus.age

      list = amelia.wishlist_for(@event)
      assert list.draft?
      assert_equal %w[drawing soccer], list.interests
      assert_equal "Draws on every napkin in the house.", list.caregiver_note
      assert_equal "love_box", @enrollment.reload.intake_step
    end

    test "a name the system did not offer is never used as the alias" do
      patch caregiver_intake_children_path,
            params: { children: { "n1" => child_fields(display_name: "Amelia Brooks") } }

      assert_equal Child::ALIASES.first, @household.children.sole.display_name
    end

    test "a child needs a first name, a birthdate, and girl or boy" do
      assert_no_difference -> { Child.count } do
        patch caregiver_intake_children_path,
              params: { children: { "n1" => { legal_first_name: "", birthdate: "", gender: "" } } }
      end

      assert_response :unprocessable_entity
      assert_select ".field-error", "First name can't be blank."
      assert_select ".field-error", "Birthdate can't be blank."
      assert_select ".field-error", "Gender must be chosen."
    end

    test "a child older than eighteen is refused" do
      assert_no_difference -> { Child.count } do
        patch caregiver_intake_children_path,
              params: { children: { "n1" => child_fields(birthdate: 19.years.ago.to_date) } }
      end

      assert_select ".field-error", "Birthdate must make them 18 or younger."
    end

    test "a sentence over 400 characters is refused" do
      patch caregiver_intake_children_path,
            params: { children: { "n1" => child_fields(caregiver_note: "a" * 401) } }

      assert_response :unprocessable_entity
      assert_select ".field-error", /too long/
    end

    test "adding another child saves nothing and keeps what was typed" do
      assert_no_difference -> { Child.count } do
        patch caregiver_intake_children_path,
              params: { add_child: "1", children: { "n1" => { legal_first_name: "Amelia" } } }
      end

      assert_select ".child-form", 2
      assert_select "input[name=?][value=?]", "children[n1][legal_first_name]", "Amelia"
      assert_select ".field-error", 0
      assert_select ".child-form .hint b", Child::ALIASES.second
    end

    test "adding another child over Turbo appends only the new one" do
      patch caregiver_intake_children_path, as: :turbo_stream,
            params: { add_child: "1", children: { "n1" => { legal_first_name: "Amelia" } } }

      assert_response :success
      assert_select "turbo-stream[action=append][target=children] template .child-form", 1
    end

    test "editing changes the same child and list" do
      list = add_child_with_list(@household, interests: [ "drawing" ])

      assert_no_difference -> { [ Child.count, Wishlist.count ].sum } do
        patch caregiver_intake_children_path, params: { children: {
          "c#{list.child_id}" => child_fields(id: list.child_id, legal_first_name: "Amelia Rose", interests: [ "baking" ])
        } }
      end

      assert_equal "Amelia Rose", list.child.reload.legal_first_name
      assert_equal [ "baking" ], list.reload.interests
    end

    test "removing a child removes their list" do
      keep = add_child_with_list(@household, first_name: "Amelia")
      drop = add_child_with_list(@household, first_name: "Marcus")

      patch caregiver_intake_children_path, params: { children: {
        "c#{keep.child_id}" => child_fields(id: keep.child_id),
        "c#{drop.child_id}" => child_fields(id: drop.child_id, legal_first_name: "Marcus", remove: "1")
      } }

      assert_redirected_to caregiver_intake_love_box_path
      assert_equal [ keep.child_id ], @household.children.reload.pluck(:id)
      assert_not Wishlist.exists?(drop.id)
    end

    test "a child whose gifts donors chose cannot be removed" do
      keep = add_child_with_list(@household, first_name: "Amelia")
      funded = add_child_with_list(@household, first_name: "Marcus")
      funded.line_items.first.fund!(build_donation(event: @event))

      patch caregiver_intake_children_path, params: { children: {
        "c#{keep.child_id}" => child_fields(id: keep.child_id),
        "c#{funded.child_id}" => child_fields(id: funded.child_id, legal_first_name: "Marcus", remove: "1")
      } }

      assert_response :unprocessable_entity
      assert_select ".form-errors", /Marcus has gifts donors already chose/
      assert Child.exists?(funded.child_id)
    end

    test "the last child cannot be removed" do
      list = add_child_with_list(@household)

      patch caregiver_intake_children_path,
            params: { children: { "c#{list.child_id}" => child_fields(id: list.child_id, remove: "1") } }

      assert_response :unprocessable_entity
      assert_select ".form-errors", /Add at least one child/
      assert Child.exists?(list.child_id)
    end

    test "changing what donors read on a live list sends it back to review" do
      list = add_child_with_list(@household, status: "live", interests: [ "drawing" ])

      patch caregiver_intake_children_path, params: { children: {
        "c#{list.child_id}" => child_fields(id: list.child_id, interests: [ "drawing", "space" ])
      } }

      assert list.reload.in_review?
    end

    private

    def child_fields(**overrides)
      { legal_first_name: "Amelia", birthdate: 9.years.ago.to_date, gender: "girl" }.merge(overrides)
    end
  end
end
