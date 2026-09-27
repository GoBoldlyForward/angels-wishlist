# frozen_string_literal: true

require_relative "funding_case"

module Admin
  # An index that queries once per row gets slower with every household and donor.
  class QueryCountTest < FundingCase
    test "the funding indexes run the same number of queries however many rows they show" do
      add_a_household_and_its_donor
      post build_admin_payouts_path
      get admin_donors_path
      before = %i[admin_donors_path admin_donations_path admin_payouts_path].to_h do |page|
        [ page, queries_during { get send(page) } ]
      end

      4.times { add_a_household_and_its_donor }
      post build_admin_payouts_path

      before.each do |page, count|
        assert_equal count, queries_during { get send(page) }, "#{page} ran more queries with more rows"
      end
    end

    test "the catalog runs the same number of queries however many items it shows" do
      category = Category.create!(name: "Toys & Games")
      CatalogItem.create!(category: category, name: "Blocks", price_in_cents: 2_000)
      get admin_catalog_items_path
      before = queries_during { get admin_catalog_items_path }

      4.times { |n| CatalogItem.create!(category: Category.create!(name: "Shelf #{n}"), name: "Gift #{n}", price_in_cents: 2_000) }

      assert_equal before, queries_during { get admin_catalog_items_path }
    end

    private

    def add_a_household_and_its_donor
      _household, _wishlist, (first, second) = build_list(asking: [ 4_000, 6_000 ])
      donation = build_donation(event: @event, donor: build_donor, gift_in_cents: 4_000, general_gift_in_cents: 1_000)
      first.fund!(donation)
      second
    end
  end
end
