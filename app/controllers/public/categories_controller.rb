# frozen_string_literal: true

module Public
  class CategoriesController < BaseController
    def show
      @filters = filters
      @page = Storefront::CategoryPage.new(current_chapter.categories.friendly.find(params[:id]), catalog: catalog, filters: filters)
    end
  end
end
