# frozen_string_literal: true

require_relative "funding_case"

module Admin
  class ImpactStatementTest < FundingCase
    setup do
      @twice = build_donor(first_name: "Priya", last_name: "Sundaram")
      2.times { build_donation(event: @event, donor: @twice) }
      @once = build_donor(first_name: "Dev", last_name: "Raghunathan")
      build_donation(event: @event, donor: @once)
      @refunded = build_donor(first_name: "Sandra", last_name: "Coyle")
      build_donation(event: @event, donor: @refunded, status: "refunded")
    end

    test "the page says how many donors will receive it and asks before sending" do
      get new_admin_impact_statement_path

      assert_response :success
      assert_select "input[type=submit][value=?]", "Send to 2 donors"
      assert_select "form[data-turbo-confirm]"
    end

    test "sending enqueues one email per donor with a completed gift" do
      assert_enqueued_emails 2 do
        post admin_impact_statement_path, params: { impact_statement: { message: "Every list was funded to 75%." } }
      end

      assert_redirected_to admin_donors_path
      assert_enqueued_email_with DonorMailer, :impact_statement, args: [ @twice, @event, "Every list was funded to 75%." ]
      assert_enqueued_email_with DonorMailer, :impact_statement, args: [ @once, @event, "Every list was funded to 75%." ]
    end

    test "an empty message sends nothing" do
      assert_no_enqueued_emails do
        post admin_impact_statement_path, params: { impact_statement: { message: " " } }
      end

      assert_response :unprocessable_entity
    end
  end
end
