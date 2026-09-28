# frozen_string_literal: true

require "test_helper"
require_relative "storefront_program"

module Public
  class HomeTest < ActionDispatch::IntegrationTest
    include StorefrontProgram

    setup do
      build_storefront
      @mayas_hoodie = ask(@maya, @hoodie, days_ago: 9)
      @mayas_art = ask(@maya, @art_set, days_ago: 8)
      @theos_hoodie = ask(@theo, @hoodie, days_ago: 7, spec: "Nike, size L", link_url: "https://www.example.com/hoodie")
    end

    test "the home page shows the season with its real numbers" do
      build_donation(event: @event, gift_in_cents: 2_000).tap { |donation| @mayas_art.fund!(donation) }

      visit root_path

      assert_response :success
      assert_select ".season-raised", /\$20\s+of \$100/
      assert_select ".season-bar i[style=?]", "width:20%"
      assert_select ".season-deadline", /Closes #{@event.closes_at.strftime("%B %-d")}/
      assert_select ".season-leg", /1\s*gifts chosen/
      assert_select ".season-leg", /2\s*children with lists/
      assert_select ".season-leg", /0\s*lists finished/
      assert_select ".season-leg", /20%\s*of the way there/
      assert_select "#faq .faq-item", 10
      assert_select "#why .why-card", 4
    end

    test "browse groups lines into one tile per product under each category in position order" do
      visit root_path

      assert_select ".sec .sec-head h2", text: "Clothes & Shoes"
      assert_select "a.tile[href=?]", gift_path(id: "hoodie"), minimum: 1
      assert_select "a.tile[href=?] .need-tag", gift_path(id: "hoodie"), text: "2 needed"
      assert_operator response.body.index("Clothes &amp; Shoes</h2>"), :<, response.body.index("Art &amp; Music</h2>")
      assert_select "a.sec-link[href=?]", category_path(id: "clothes-shoes")
    end

    test "a custom line is a tile of its own" do
      ask(@theo, nil, days_ago: 3, name: "Purple scooter")

      visit root_path

      assert_select "a.tile[href=?] .tile-name", gift_path(id: "#{@theo.slug}--purple-scooter"), text: "Purple scooter"
    end

    test "the shelves follow their rules and step aside once a filter is set" do
      nova = build_listed_child(build_private_household, "Nova", age: 6, gender: "girl", approved_at: 2.days.ago)
      ask(nova, @art_set, days_ago: 1)

      visit root_path

      assert_select ".shelf h2", /One gift from a finished list/
      assert_select ".shelf h2", /Nobody has funded these yet/
      assert_select ".shelf h2", /Everything under \$40/
      assert_select ".shelf h2", /Teenagers get skipped/
      assert_select ".shelf h2", /New lists this week/
      assert_select ".shelf", text: /New lists this week.*Nova, 6/m
      assert_select ".shelf", text: /New lists this week.*Maya, 9/m, count: 0

      visit root_path(gender: "girl")

      assert_select ".shelf", 0
    end

    test "filters narrow the grid to one flat list with a count" do
      visit root_path(price: "u25")

      assert_select ".sec-head h2", "1 gift matches"
      assert_select ".grid a.tile", 1
      assert_select ".grid a.tile .tile-name", "Art supply set"

      visit root_path(age: "13-18")

      assert_select ".grid a.tile", 1
      assert_select ".grid a.tile .tile-for", /For Theo, 14/

      visit root_path(gender: "girl", price: "25-50")

      assert_select ".grid a.tile .tile-for", /For Maya, 9/
      assert_select "a.btn-plain", "Clear all"
    end

    test "by child shows a card for each child with a visible list" do
      build_donation(event: @event, gift_in_cents: 2_000).tap { |donation| @mayas_art.fund!(donation) }

      visit root_path(tab: "children")

      assert_response :success
      assert_select "a.kid-card", 2
      assert_select "a.kid-card[href=?]", child_path(id: @maya.slug) do
        assert_select ".kid-name", "Maya, 9"
        assert_select ".kid-meta", "Girl · DeKalb County"
        assert_select ".tags .tag", 3
        assert_select ".fund-line", /\$20\s+of \$60 chosen/
        assert_select ".fund-line", /1 gift left/
        assert_select ".bar i[style=?]", "width:33%"
      end
    end

    test "still unfunded lists every open gift by product, most needed first" do
      visit root_path(tab: "unfunded")

      assert_response :success
      assert_select ".sec-head p", /3 gifts across 2 products, most-needed first/
      assert_select ".grid a.tile .tile-name" do |names|
        assert_equal [ "Hoodie", "Art supply set" ], names.map { |name| name.text.strip }
      end
    end

    test "give any amount offers the presets and a custom amount" do
      visit root_path(tab: "give")

      assert_response :success
      [ 25, 50, 100, 250 ].each do |dollars|
        assert_select "form[action=?] input[name=amount][value=?]", cart_general_gifts_path, dollars.to_s
      end
      assert_select "input[type=number][name=amount][min=?]", "5"
      assert_select "body", text: /furthest-behind|closest-to-complete/, count: 0
    end

    test "a list from a household that is not verified never appears" do
      pending_home = build_household(organization: @chapter, verification_status: "pending")
      hidden = build_listed_child(pending_home, "Wren", age: 7, gender: "girl")
      ask(hidden, @art_set, days_ago: 2)

      visit root_path(tab: "children")
      assert_select "a.kid-card", 2
      assert_no_match(/Wren/, response.body)

      visit root_path(tab: "unfunded")
      assert_select ".sec-head p", /3 gifts across 2 products/

      visit child_path(id: hidden.slug)
      assert_response :not_found
    end

    test "a list in review or a line awaiting review stays out of sight" do
      ask(@maya, @art_set, days_ago: 1, status: "needs_review", price_in_cents: 9_900, name: "Deluxe art case")
      in_review = build_listed_child(@household, "Sage", age: 5, gender: "girl", status: "in_review")
      ask(in_review, @hoodie, days_ago: 1)

      visit root_path(tab: "unfunded")

      assert_no_match(/Deluxe art case/, response.body)
      assert_no_match(/Sage/, response.body)
    end

    test "the home page still renders with no open event" do
      @event.update!(closes_at: 1.day.ago)

      visit root_path

      assert_response :success
      assert_select "h2", "The lists are closed for this season"
    end

    test "the home page loads every list in a fixed number of queries" do
      visit root_path
      baseline = count_queries { visit root_path }

      3.times do |index|
        list = build_listed_child(build_private_household, "Child #{index}", age: 8, gender: "boy")
        ask(list, @hoodie, days_ago: 2)
        ask(list, @art_set, days_ago: 1)
      end

      assert_equal baseline, count_queries { visit root_path }
    end

    private

    def count_queries(&block)
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
      count
    end
  end
end
