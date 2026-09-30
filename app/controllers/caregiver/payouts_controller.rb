# frozen_string_literal: true

module Caregiver
  class PayoutsController < IntakeController
    self.step = "payout"

    def show
      sync_stripe
      @form = Intake::PayoutForm.new(enrollment: current_enrollment)
    end

    def update
      @form = Intake::PayoutForm.new(enrollment: current_enrollment, attributes: payout_params)
      return render :show, status: :unprocessable_entity unless @form.save

      continue_to(:review)
    end

    private

    # Stripe sends the caregiver back here whether or not they finished its form.
    def sync_stripe
      PaymentGateway.sync_onboarding(current_household)
    rescue Stripe::StripeError
      flash.now[:alert] = "Stripe could not be reached to check your account. Try again in a moment."
    end

    def payout_params
      params.expect(payout: %i[payout_method agreed street_line_1 city zipcode])
    end
  end
end
