# frozen_string_literal: true

class AddChapterDebitsToPayouts < ActiveRecord::Migration[8.1]
  def change
    change_table :payouts, bulk: true do |t|
      t.string :stripe_debit_id
      t.integer :debited_in_cents
    end
  end
end
