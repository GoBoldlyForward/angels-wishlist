# frozen_string_literal: true

module Public
  class GiftsController < BaseController
    def show
      @product = catalog.product(params[:id]) || raise(ActiveRecord::RecordNotFound)
    end
  end
end
