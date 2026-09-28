# frozen_string_literal: true

module Public
  module Carts
    class GiftsController < BaseController
      def create
        added_to_cart cart.add_gift(params[:gift]), fallback: cart_path
      end

      def destroy
        cart.remove_gift(params[:id])
        session[:open_cart] = true

        redirect_back_or_to cart_path, status: :see_other
      end
    end
  end
end
