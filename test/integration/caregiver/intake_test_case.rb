# frozen_string_literal: true

require "test_helper"

module Caregiver
  class IntakeTestCase < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    setup do
      @chapter = build_organization(name: "Atlanta Angels")
      @event = build_event(organization: @chapter, love_box_options: LoveBox::DEFAULT_GROUPS)
    end

    private

    # A household part way through intake: nothing chosen, nothing agreed.
    def start_household(caregiver: users(:caregiver), step: "review", **attrs)
      household = build_household(organization: @chapter, caregiver: caregiver, verification_status: "pending",
                                  payout_method: "none", stripe_account_id: nil, county: "Clayton", **attrs)
      enrollment = Enrollment.create!(household: household, event: @event, intake_step: step)
      [ household, enrollment ]
    end

    def add_child_with_list(household, first_name: "Amelia", gifts: [ [ "Skateboard and helmet", 6_000 ] ], **list_attrs)
      child = build_child(household: household, legal_first_name: first_name)
      list = build_wishlist(child: child, event: @event, status: "draft", **list_attrs)
      gifts.each { |name, cents| build_line_item(wishlist: list, name: name, price_in_cents: cents) }
      list
    end

    def full_love_box
      @event.love_box_groups.to_h { |group| [ group.id, { picks: [ group.options.first ], count: 2 } ] }
    end

    def make_ready(household, enrollment)
      enrollment.love_box_selection.assign(full_love_box)
      enrollment.save!
      enrollment.agree_to_spending!
      household.update!(payout_method: "stripe", stripe_account_id: "acct_test_ready", stripe_onboarded_at: Time.current)
    end

    # Loads the form first, as a person would, so the spam check has its token.
    def submit_home(fields, **extra)
      get caregiver_intake_home_path
      spinner = css_select("input[name=spinner]").first["value"]
      post caregiver_intake_home_path, params: { home: fields, spinner: spinner }.merge(extra)
    end

    def home_fields(**overrides)
      { first_name: "Tanya", last_name: "Okafor", email: "tanya.okafor@example.com", password: "password123",
        phone: "(404) 867-5309", county: "DeKalb", street_line_1: "1420 Peachtree Way", city: "Decatur",
        zipcode: "30030" }.merge(overrides)
    end
  end
end
