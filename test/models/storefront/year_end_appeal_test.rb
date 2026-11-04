# frozen_string_literal: true

require "test_helper"

module Storefront
  class YearEndAppealTest < ActiveSupport::TestCase
    test "a chapter that has not edited anything gets the bundled appeal, named for it" do
      appeal = YearEndAppeal.new(chapter: build_organization(name: "Austin Angels"))

      assert appeal.enabled?
      assert_equal "The lists are for December. Austin Angels is there all year.", appeal.headline
      assert_equal 4, appeal.stats.size
      assert_equal [ 50, 100, 250, 500, 1_000, 2_500, 5_000 ], appeal.tiers.map(&:dollars)
      assert_equal "$5,000+", appeal.tiers.last.amount_label
      assert_equal "Their day, remembered", appeal.tier_for(25_000).title
    end

    test "what staff saved wins, field by field, and tiers sort smallest first" do
      chapter = build_organization(name: "Atlanta Angels", year_end_appeal: {
        "headline" => "Our year.", "lede" => "",
        "tiers" => [ { "dollars" => 500, "title" => "B" }, { "dollars" => 20, "title" => "A" } ]
      })
      appeal = YearEndAppeal.new(chapter: chapter)

      assert_equal "Our year.", appeal.headline
      assert_equal "", appeal.lede
      assert_equal "January through June 2026", appeal.period
      assert_equal [ [ "$20", "A" ], [ "$500+", "B" ] ], appeal.tiers.map { |tier| [ tier.amount_label, tier.title ] }
      assert_nil appeal.tier_for(5_000)
    end

    test "without a chapter it still reads" do
      assert_equal "The lists are for December. Atlanta Angels is there all year.", YearEndAppeal.new(chapter: nil).headline
    end
  end
end
