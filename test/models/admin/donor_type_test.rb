# frozen_string_literal: true

require "test_helper"

module Admin
  class DonorTypeTest < ActiveSupport::TestCase
    test "a name with a group word is a group" do
      [ "Buckhead Rotary", "Emory service group", "Piedmont Church youth group", "Grady Nurses Foundation",
        "Eastside run crew", "Acme Company" ].each do |name|
        assert_equal "group", DonorType.for(name).key, name
      end
    end

    test "a family or household is a family" do
      assert_equal "family", DonorType.for("The Hollis family").key
      assert_equal "family", DonorType.for("Reyes Household").key
    end

    test "a church family is a group, because group words win" do
      assert_equal "group", DonorType.for("The Piedmont Church family").key
    end

    test "anyone else is an individual" do
      assert_equal "individual", DonorType.for("Priya Sundaram").key
      assert_equal "individual", DonorType.for("").key
      assert_equal "Individual", DonorType.for(nil).label
    end

    test "the type is read off the name and never the email" do
      donor = build_donor(first_name: nil, last_name: nil, email: "rotary-treasurer@example.com")

      assert_equal "individual", DonorType.of(donor).key
    end

    test "narrowing in the database agrees with the name rule" do
      donors = [ %w[Buckhead Rotary], [ "The Hollis", "family" ], [ "The Piedmont Church", "family" ],
                 %w[Priya Sundaram], [ nil, nil ] ].map { |first, last| build_donor(first_name: first, last_name: last) }

      %w[individual family group].each do |key|
        expected = donors.select { |donor| DonorType.of(donor).key == key }
        assert_equal expected.map(&:id).sort, DonorType.narrow(User.where(id: donors), key).pluck(:id).sort, key
      end
    end
  end
end
