# frozen_string_literal: true

module Public
  class DonationsController < BaseController
    def show
      donation = Donation.find_by!(uuid: params[:uuid])
      donation = PaymentGateway.confirm(donation, params[:session_id])

      @receipt = Storefront::Receipt.new(donation)
      @closes_at = donation.event.closes_at
    end
  end
end
