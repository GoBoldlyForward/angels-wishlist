# frozen_string_literal: true

require_relative "funding_case"

module Admin
  class EventsTest < FundingCase
    test "the list and the event page render" do
      get admin_events_path
      assert_response :success
      assert_select "td", text: /Christmas 2026/

      get admin_event_path(@event)
      assert_response :success
      assert_select "h1", text: "Christmas 2026"
    end

    test "a new event starts from the standard Love Box" do
      get new_admin_event_path

      assert_response :success
      assert_select "[data-admin-love-box-target=list] [data-admin-love-box-target=group]", LoveBox::DEFAULT_GROUPS.size
      assert_select "input[name=?][value=?]", "event[per_child_cap_in_dollars]", "200"
    end

    test "creating an event takes dollars and the Love Box groups" do
      assert_difference -> { Event.count }, 1 do
        post admin_events_path, params: { event: {
          name: "Christmas 2027", opened_at: "2027-10-05T09:00", closes_at: "2027-12-07T23:59",
          payout_at: "2027-12-08T09:00", per_child_cap_in_dollars: "175.50", love_box_edited: "1",
          love_box_groups: {
            "0" => { id: "drink", label: "Family drink", options: "Hot chocolate\r\nApple cider\r\n\r\nNo thank you",
                     picks: "1" },
            "1712" => { id: "", label: "Family game", options: "Uno\nTaboo", picks: "2", large_household_only: "1" },
            "1713" => { id: "", label: "", options: "Dropped", picks: "1" }
          }
        } }
      end

      event = Event.order(:id).last
      assert_redirected_to admin_event_path(event)
      assert_equal @chapter, event.organization
      assert_equal 17_550, event.per_child_cap_in_cents
      assert_equal Time.zone.local(2027, 10, 5, 9), event.opened_at
      assert_equal %w[drink family_game], event.love_box_groups.map(&:id)
      assert_equal [ "Hot chocolate", "Apple cider", "No thank you" ], event.love_box_groups.first.options
      assert event.love_box_groups.last.large_household_only
      assert_equal 2, event.love_box_groups.last.picks
    end

    test "an event without a name or a cap is refused" do
      assert_no_difference -> { Event.count } do
        post admin_events_path, params: { event: { name: "", per_child_cap_in_dollars: "lots" } }
      end

      assert_response :unprocessable_entity
      assert_select ".alert-danger", text: /cap per child/
    end

    test "editing an event changes its dates, cap, and Love Box" do
      @event.update!(love_box_options: LoveBox::DEFAULT_GROUPS)

      patch admin_event_path(@event), params: { event: {
        name: "Holiday 2026", per_child_cap_in_dollars: "250", love_box_edited: "1",
        love_box_groups: { "0" => { id: "holiday", label: "Holiday celebrated", options: "Christmas\nHanukkah", picks: "1" } }
      } }

      assert_redirected_to admin_event_path(@event.reload)
      assert_equal "Holiday 2026", @event.name
      assert_equal 25_000, @event.per_child_cap_in_cents
      assert_equal [ "holiday" ], @event.love_box_groups.map(&:id)
    end

    test "saving without touching the Love Box keeps it" do
      @event.update!(love_box_options: LoveBox::DEFAULT_GROUPS)

      patch admin_event_path(@event), params: { event: { name: "Holiday 2026" } }

      assert_equal LoveBox::DEFAULT_GROUPS.size, @event.reload.love_box_groups.size
    end

    test "lowering the cap below what lists ask for saves with a warning" do
      build_list(asking: [ 15_000, 4_000 ])
      build_list(asking: [ 9_000 ])

      get edit_admin_event_path(@event)
      assert_select ".privacy-note", text: /largest list asks for \$190\.00/

      patch admin_event_path(@event), params: { event: { per_child_cap_in_dollars: "100" } }

      assert_equal 10_000, @event.reload.per_child_cap_in_cents
      assert_match(/\A1 list already asks for more than the cap/, flash[:alert])
    end
  end
end
