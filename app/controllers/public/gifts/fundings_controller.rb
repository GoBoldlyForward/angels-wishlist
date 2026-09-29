# frozen_string_literal: true

module Public
  module Gifts
    class FundingsController < BaseController
      def create
        catalog_item = current_chapter.catalog_items.friendly.find(params[:gift_id])

        added_to_cart cart.add_pooled(catalog_item, params[:quantity]), fallback: gift_path(catalog_item)
      end

      def destroy
        product = catalog.product(params[:gift_id]) || raise(ActiveRecord::RecordNotFound)
        cart.remove_product(product)

        redirect_back_or_to gift_path(product.key), status: :see_other, notice: "Taken out of your cart."
      end
    end
  end
end
