# frozen_string_literal: true

class AddStockPhotoToCatalogItems < ActiveRecord::Migration[8.1]
  def change
    # A bundled image under app/assets/images, shown until a photo is uploaded.
    add_column :catalog_items, :stock_photo, :string
  end
end
