# frozen_string_literal: true

require_relative "funding_case"

module Admin
  class YearEndAppealTest < FundingCase
    test "the page starts from the bundled appeal" do
      get admin_year_end_appeal_path

      assert_response :success
      assert_select "h1", "Year-end appeal"
      assert_select "input[name=?][checked]", "year_end_appeal[enabled]"
      assert_select "input[name=?][value=?]", "year_end_appeal[headline]",
                    "The lists are for December. Atlanta Angels is there all year."
      assert_select "input[name=?][value=?]", "year_end_appeal[stats][0][figure]", "163"
      assert_select "input[name=?][value=?]", "year_end_appeal[tiers][6][dollars]", "5000"
      assert_select "textarea[name=?]", "year_end_appeal[tiers][6][body]", /Dare to Dream/
    end

    test "saving keeps the words, the figures, and the tiers on the chapter" do
      patch admin_year_end_appeal_path, params: { year_end_appeal: {
        enabled: "1", headline: "This year, 300 kids.", lede: "A short paragraph.", period: "All of 2026",
        source_label: "our annual report", source_url: "",
        stats: { "0" => { figure: "300", label: "kids served" }, "1" => { figure: "", label: "" } },
        tiers: { "0" => { dollars: "$1,000", title: "A year of mentoring", teaser: "", body: "Funds a match." },
                 "1" => { dollars: "75", title: "Shoes", teaser: "Their pick.", body: "" },
                 "2" => { dollars: "", title: "", teaser: "", body: "" } }
      } }

      assert_redirected_to admin_year_end_appeal_path
      appeal = Storefront::YearEndAppeal.new(chapter: @chapter.reload)
      assert appeal.enabled?
      assert_equal "This year, 300 kids.", appeal.headline
      assert_equal [ [ "300", "kids served" ] ], appeal.stats.map { |stat| [ stat.figure, stat.label ] }
      assert_equal [ [ 75, "$75", "Shoes" ], [ 1_000, "$1,000+", "A year of mentoring" ] ],
                   appeal.tiers.map { |tier| [ tier.dollars, tier.amount_label, tier.title ] }
      assert_equal "", appeal.source_url
    end

    test "switching the appeal off hides it at checkout" do
      patch admin_year_end_appeal_path, params: { year_end_appeal: { enabled: "0" } }

      assert_not Storefront::YearEndAppeal.new(chapter: @chapter.reload).enabled?
      assert_equal "The lists are for December. Atlanta Angels is there all year.",
                   Storefront::YearEndAppeal.new(chapter: @chapter).headline
    end

    test "a blank headline, a half-filled figure, or a tier under five dollars is refused" do
      patch admin_year_end_appeal_path, params: { year_end_appeal: {
        headline: "", stats: { "0" => { figure: "12", label: "" } },
        tiers: { "0" => { dollars: "4.50", title: "" } }
      } }

      assert_response :unprocessable_entity
      assert_select ".alert-danger li", "Give the appeal a headline"
      assert_select ".alert-danger li", "Each figure needs a number and a label"
      assert_select ".alert-danger li", "Each tier needs a title"
      assert_select ".alert-danger li", "Tier amounts are whole dollars, $5 or more"
      assert_equal({}, @chapter.reload.year_end_appeal)
    end
  end
end
