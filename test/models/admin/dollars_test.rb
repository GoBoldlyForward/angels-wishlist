# frozen_string_literal: true

require "test_helper"

module Admin
  class DollarsTest < ActiveSupport::TestCase
    test "dollars become whole cents without floating point drift" do
      assert_equal 20_000, Dollars.to_cents("200")
      assert_equal 1_999, Dollars.to_cents("19.99")
      assert_equal 6_499, Dollars.to_cents("$64.99")
      assert_equal 125_000, Dollars.to_cents("1,250")
      assert_equal 3_501, Dollars.to_cents(35.005)
    end

    test "something that is not an amount is nil" do
      assert_nil Dollars.to_cents("")
      assert_nil Dollars.to_cents(nil)
      assert_nil Dollars.to_cents("lots")
    end

    test "cents read back as dollars, whole when they can be" do
      assert_equal "200", Dollars.from_cents(20_000)
      assert_equal "19.99", Dollars.from_cents(1_999)
      assert_equal "0.05", Dollars.from_cents(5)
      assert_nil Dollars.from_cents(nil)
    end
  end
end
