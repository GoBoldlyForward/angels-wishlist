# frozen_string_literal: true

module Admin
  # Hands an organizer to Stripe's hosted onboarding for the chapter's account and takes them back.
  class StripeConnectionsController < BaseController
    def show
      PaymentGateway.refresh_chapter(current_chapter)
      if current_chapter.stripe_charges_enabled?
        redirect_to admin_organization_path(current_chapter), notice: "Stripe is connected. Donations can be taken."
      else
        redirect_to admin_organization_path(current_chapter),
                    alert: "Stripe still needs a few details before donations can be taken."
      end
    rescue Stripe::StripeError
      redirect_to admin_organization_path(current_chapter), alert: "Stripe could not be reached. Try again in a moment."
    end

    def create
      redirect_to PaymentGateway.chapter_onboarding_url(current_chapter, return_url: admin_stripe_connection_url,
                                                                         refresh_url: admin_stripe_connection_url),
                  allow_other_host: true, status: :see_other
    rescue Stripe::StripeError
      redirect_to admin_organization_path(current_chapter), status: :see_other,
                  alert: "Stripe could not be reached. Try again in a moment."
    end
  end
end
