# frozen_string_literal: true

module Public
  class DonationsController < BaseController
    def show
      donation = Donation.find_by!(uuid: params[:uuid])
      donation = PaymentGateway.confirm(donation, params[:session_id])

      @receipt = Storefront::Receipt.new(donation)
      @closes_at = donation.event.closes_at
    end

    def update
      donation = Donation.succeeded.find_by!(uuid: params[:uuid])

      if donation.update(heard_about_params)
        redirect_to donation_path(donation), status: :see_other
      else
        redirect_to donation_path(donation), status: :see_other,
                                             alert: "Pick one of the answers below, or tell us in your own words."
      end
    end

    private

    def heard_about_params
      params.expect(donation: %i[heard_about heard_about_other])
    end
  end
end
