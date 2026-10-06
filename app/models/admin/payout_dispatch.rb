# frozen_string_literal: true

module Admin
  # Sends one payout, by transfer or by recording the gift card ordered through
  # Tremendous, and tells the caregiver.
  class PayoutDispatch
    attr_reader :payout, :error

    def initialize(payout, order_id: nil, share_in_cents: nil)
      @payout = payout
      @order_id = order_id.to_s.strip
      @share_in_cents = share_in_cents
    end

    def call
      @error = refusal
      return false if @error

      payout.refresh! if payout.failed?
      deliver
      return failed unless payout.sent?

      CaregiverMailer.payout_sent(payout).deliver_later
      true
    end

    # Why this payout cannot go out, or nil when it can.
    def refusal
      return "This payout has already been sent." if payout.sent? || payout.delivered?
      return payout.blocker if payout.blocker
      return "Only a scheduled payout can be sent. Build payouts again to bring this one up to date." unless ready?
      return "There is nothing to send. This household's share is $0." unless share_in_cents.positive?
      return "The pool has changed since this payout was built. Build payouts again before sending." if stale?

      nil
    end

    def sendable?
      refusal.nil?
    end

    private

    def ready?
      payout.scheduled? || payout.failed?
    end

    def stale?
      payout.scheduled? && payout.amount_in_cents != share_in_cents
    end

    def share_in_cents
      @share_in_cents ||= payout.share_in_cents
    end

    def deliver
      if payout.via_stripe?
        PaymentGateway.transfer(payout)
      else
        payout.mark_sent!(gift_card_order_id: @order_id)
      end
    end

    def failed
      @error = "The transfer did not go through. #{payout.hold_reason}"
      false
    end
  end
end
