# frozen_string_literal: true

module Public
  module Categories
    class FundingsController < BaseController
      def create
        category = current_chapter.categories.friendly.find(params[:category_id])
        quantity = params[:whole_category].present? ? nil : params[:quantity]

        added_to_cart cart.add_from_category(category, quantity), fallback: category_path(category)
      end
    end
  end
end
