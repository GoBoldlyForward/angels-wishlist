# frozen_string_literal: true

require "test_helper"

module Admin
  # A chapter with one open event and staff signed in, which every funding and setup page needs.
  class FundingCase < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include ActionMailer::TestHelper

    setup do
      @chapter = build_organization(name: "Atlanta Angels")
      @event = build_event(organization: @chapter, name: "Christmas 2026")
      sign_in users(:staff)
    end

    private

    # A verified household with one child whose live list asks for the given amounts.
    def build_list(asking: [ 10_000 ], **household_attrs)
      household = build_household(organization: @chapter, **household_attrs)
      wishlist = build_wishlist(child: build_child(household: household), event: @event)
      lines = asking.map { |cents| build_line_item(wishlist: wishlist, price_in_cents: cents) }
      [ household, wishlist, lines ]
    end

    def csv_rows
      CSV.parse(response.body, headers: true)
    end

    def queries_during
      count = 0
      counter = ->(*, payload) { count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
      count
    end
  end
end
