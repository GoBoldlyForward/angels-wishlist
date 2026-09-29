# frozen_string_literal: true

class AddApplicationFeesToDonations < ActiveRecord::Migration[8.1]
  def change
    change_table :donations, bulk: true do |t|
      t.integer :platform_fee_in_cents, default: 0, null: false
      t.integer :processing_fee_in_cents, default: 0, null: false
    end
  end
end
