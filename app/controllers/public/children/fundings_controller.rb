# frozen_string_literal: true

module Public
  module Children
    class FundingsController < BaseController
      def create
        added_to_cart cart.add_list(params[:child_id]), fallback: child_path(params[:child_id])
      end
    end
  end
end
