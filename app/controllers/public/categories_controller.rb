# frozen_string_literal: true

module Public
  class CategoriesController < BaseController
    def show
      @category = Category.friendly.find(params[:id])
      @catalog = catalog
      @filters = filters
      @gifts = catalog.category_gifts(@category)
    end
  end
end
