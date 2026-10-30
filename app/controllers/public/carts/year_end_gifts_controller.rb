# frozen_string_literal: true

module Public
  module Carts
    class YearEndGiftsController < BaseController
      def create
        if cart.set_year_end_gift_in_dollars(chosen_amount)
          flash[:notice] = "Your year-end gift was added to your donation."
        else
          flash[:alert] = "A year-end gift is #{helpers.money(Donation::MINIMUM_GENERAL_GIFT_IN_CENTS)} or more."
        end
        redirect_to checkout_path, status: :see_other
      end

      def destroy
        cart.remove_year_end_gift
        redirect_to checkout_path, status: :see_other
      end

      private

      def chosen_amount
        params[:amount] == "custom" ? params[:custom_amount] : params[:amount]
      end
    end
  end
end
