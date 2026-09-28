# frozen_string_literal: true

module Public
  module Carts
    class GeneralGiftsController < BaseController
      def create
        if cart.add_general_gift_in_dollars(params[:amount])
          session[:open_cart] = true
          flash[:notice] = "Your gift was added to your cart."
        else
          flash[:alert] = "A general gift is #{helpers.money(Donation::MINIMUM_GENERAL_GIFT_IN_CENTS)} or more."
        end
        redirect_back_or_to root_path(tab: "give", anchor: "shop"), status: :see_other
      end

      def destroy
        cart.remove_general_gift(params[:id])
        session[:open_cart] = true

        redirect_back_or_to cart_path, status: :see_other
      end
    end
  end
end
