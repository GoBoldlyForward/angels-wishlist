# frozen_string_literal: true

require_relative "families_test_case"

module Admin
  class LoveBoxTest < FamiliesTestCase
    setup do
      @brooks, = build_family(county: "Clayton County")
      @sinclair, = build_family(name: "The Sinclair home", alias_name: "Ruby", verification_status: "pending",
                                county: "Douglas County")
      @unsubmitted, = build_family(name: "The Vance home", alias_name: "Theo")
      enroll(@brooks, picks: { "drink" => { "picks" => [ "Hot chocolate" ] },
                               "cups" => { "picks" => [ "One holiday mug per caregiver" ], "count" => 2 },
                               "cozy" => { "picks" => [ LoveBox::DECLINED ] } })
      enroll(@sinclair, picks: { "drink" => { "picks" => [ "Hot chocolate" ] },
                                 "cups" => { "picks" => [ "One holiday mug per caregiver" ], "count" => 1 },
                                 "grocery" => { "picks" => [ "Publix" ] } })
      enroll(@unsubmitted, picks: { "drink" => { "picks" => [ "Apple cider" ] } }, submitted: false)
    end

    test "the packing list totals each item across submitted households" do
      get admin_love_box_path

      assert_response :success
      totals = css_select(".packing-totals .packing-card").to_h do |card|
        [ card.css("h4").text, card.css("dt").map(&:text).zip(card.css("dd").map { |dd| dd.text.to_i }).to_h ]
      end
      assert_equal({ "Hot chocolate" => 2 }, totals["Family drink"])
      assert_equal({ "One holiday mug per caregiver" => 3 }, totals["Festive cups"])
      assert_equal({ "Publix" => 1 }, totals["$25 grocery gift card"])
      assert_not totals.key?("Cozy item")
    end

    test "each submitted household has a card with its choices" do
      get admin_love_box_path

      cards = css_select(".packing-boxes .packing-card")
      assert_equal [ "The Brooks home", "The Sinclair home" ], cards.map { |card| card.css("h3").text.strip }
      assert_includes cards.first.text, "Clayton County"
      assert_includes cards.first.text, "1 child"
      assert_includes cards.first.css(".status-badge").text, "Verified"
      assert_includes cards.last.css(".status-badge").text, "Pending"
      assert_includes cards.first.css("dd").map(&:text), "One holiday mug per caregiver (2)"
    end

    test "the packing list exports each household's box to CSV" do
      get admin_love_box_path(format: :csv)

      rows = csv_rows
      assert_equal [ "The Brooks home", "The Sinclair home" ], rows.map { |row| row["Household"] }
      assert_equal "Hot chocolate", rows.first["Family drink"]
      assert_equal "yes", rows.first["Verified"]
      assert_equal "no", rows.last["Verified"]
      assert_equal "Publix", rows.last["$25 grocery gift card"]
    end

    test "the totals export to CSV" do
      get admin_love_box_path(format: :csv, sheet: "totals")

      rows = csv_rows.map(&:fields)
      assert_includes rows, [ "Family drink", "Hot chocolate", "2" ]
      assert_includes rows, [ "Festive cups", "One holiday mug per caregiver", "3" ]
    end
  end
end
