# frozen_string_literal: true

module Caregiver
  # Hands the caregiver to Stripe's hosted onboarding and takes them back at the payout step.
  class StripeConnectionsController < IntakeController
    self.step = "payout"

    def create
      current_household.update!(payout_method: "stripe")
      redirect_to PaymentGateway.onboarding_url(current_household, return_url: caregiver_intake_payout_url,
                                                                   refresh_url: caregiver_intake_payout_url),
                  allow_other_host: true, status: :see_other
    rescue Stripe::StripeError
      redirect_to caregiver_intake_payout_path, status: :see_other,
                  alert: "Stripe could not be reached. Try again in a moment."
    end
  end
end
