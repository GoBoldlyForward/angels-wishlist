# frozen_string_literal: true

class AddCartToDonations < ActiveRecord::Migration[8.1]
  def change
    # What the donor chose, held until the payment settles: { "line_item_ids" => [...] }
    add_column :donations, :cart, :jsonb, null: false, default: {}
  end
end
