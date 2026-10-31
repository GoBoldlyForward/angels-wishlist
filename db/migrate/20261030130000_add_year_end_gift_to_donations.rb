# frozen_string_literal: true

class AddYearEndGiftToDonations < ActiveRecord::Migration[8.0]
  def change
    add_column :donations, :year_end_gift_in_cents, :integer, default: 0, null: false
  end
end
