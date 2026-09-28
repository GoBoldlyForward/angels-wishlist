# frozen_string_literal: true

module Public
  class CategoriesController < BaseController
    def show
      @filters = filters
      @page = Storefront::CategoryPage.new(Category.friendly.find(params[:id]), catalog: catalog, filters: filters)
    end
  end
end
