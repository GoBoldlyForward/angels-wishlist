# frozen_string_literal: true

module Admin
  class CategoriesController < BaseController
    before_action :set_category, only: %i[edit update destroy]

    def index
      @categories = current_chapter.categories.ordered
      @item_counts = current_chapter.catalog_items.group(:category_id).count
    end

    def new
      @category = current_chapter.categories.new(tint: "t1")
    end

    def create
      @category = current_chapter.categories.new(category_params)

      if @category.save
        redirect_to admin_categories_path, notice: "#{@category.name} is added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @category.update(category_params)
        redirect_to admin_categories_path, notice: "Saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @category.destroy
        redirect_to admin_categories_path, notice: "#{@category.name} is deleted."
      else
        redirect_to admin_categories_path, alert: "#{@category.name} still has catalog items. Move or delete them first."
      end
    end

    private

    def set_category
      @category = current_chapter.categories.friendly.find(params[:id])
    end

    def category_params
      params.expect(category: %i[name icon tint headline blurb position])
    end
  end
end
