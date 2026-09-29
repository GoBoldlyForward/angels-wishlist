# frozen_string_literal: true

module Admin
  class CatalogItemsController < BaseController
    before_action :set_catalog_item, only: %i[edit update destroy]

    def index
      @table = CatalogTable.new(current_chapter, params)

      respond_to do |format|
        format.html { @pagy, @rows = pagy(:offset, @table.rows) }
        format.csv { send_csv(@table, CatalogTable::CSV_COLUMNS, "catalog") }
      end
    end

    def new
      @form = CatalogItemForm.new(current_chapter.catalog_items.new(category_id: params[:category_id]))
    end

    def create
      @form = CatalogItemForm.new(current_chapter.catalog_items.new, catalog_item_params)
      save_and_return(:new, "#{@form.name} is in the catalog.")
    end

    def edit
      @form = CatalogItemForm.new(@catalog_item)
    end

    def update
      @form = CatalogItemForm.new(@catalog_item, catalog_item_params)
      save_and_return(:edit, "Saved.")
    end

    def destroy
      @catalog_item.destroy!
      redirect_to admin_catalog_items_path, notice: "#{@catalog_item.name} is deleted. Lists that asked for it keep their gift."
    end

    private

    def set_catalog_item
      @catalog_item = current_chapter.catalog_items.friendly.find(params[:id])
    end

    def save_and_return(template, notice)
      if @form.save
        redirect_to admin_catalog_items_path, notice: notice, alert: @form.photo_error
      else
        render template, status: :unprocessable_entity
      end
    end

    def catalog_item_params
      params.expect(catalog_item: %i[name category_id price_in_dollars min_age max_age icon active photo
                                     photo_attribution])
    end
  end
end
