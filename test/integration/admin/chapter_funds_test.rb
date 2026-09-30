# frozen_string_literal: true

require_relative "funding_case"

module Admin
  class ChapterFundsTest < FundingCase
    setup do
      @chapter.update!(stripe_account_id: "acct_chapter", stripe_charges_enabled: true)
      @by_deposit, = build_list(asking: [ 10_000 ], payout_method: "stripe")
      @by_card, = build_list(asking: [ 10_000 ], payout_method: "gift_card")
      build_donation(event: @event, gift_in_cents: 0, general_gift_in_cents: 20_000)
    end

    test "direct deposit shares are held and the rest is free to send" do
      with_balance(25_000) { get admin_chapter_funds_path }

      assert_response :success
      assert_select ".stat-card", /Held for caregivers\s*\$100\.00/
      assert_select ".stat-card", /Free to send\s*\$150\.00/
    end

    test "a share already paid is no longer held" do
      @event.build_payouts!
      @event.payouts.find_by!(household: @by_deposit).update!(status: "sent", debited_in_cents: 10_000)

      with_balance(15_000) { get admin_chapter_funds_path }

      assert_select ".stat-card", /Held for caregivers\s*\$0\.00/
      assert_select ".stat-card", /Free to send\s*\$150\.00/
    end

    test "sending more than is free is refused" do
      released = nil

      with_balance(25_000) do
        swapping(PaymentGateway, :release_to_bank, ->(_chapter, cents) { released = cents }) do
          post release_admin_chapter_funds_path, params: { amount_in_dollars: "200" }
        end
      end

      assert_redirected_to admin_chapter_funds_path
      assert_match(/Only 150 is free to send/, flash[:alert])
      assert_nil released
    end

    test "what is free goes to the chapter's bank" do
      released = nil

      with_balance(25_000) do
        swapping(PaymentGateway, :release_to_bank, ->(_chapter, cents) { released = cents }) do
          post release_admin_chapter_funds_path, params: { amount_in_dollars: "150" }
        end
      end

      assert_equal 15_000, released
      assert_equal "$150.00 is on its way to the chapter's bank.", flash[:notice]
    end

    private

    def with_balance(cents, &)
      swapping(PaymentGateway, :chapter_balance_in_cents, ->(_chapter) { cents }, &)
    end
  end
end
