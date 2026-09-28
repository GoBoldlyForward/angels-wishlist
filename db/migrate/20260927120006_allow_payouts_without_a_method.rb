# frozen_string_literal: true

class AllowPayoutsWithoutAMethod < ActiveRecord::Migration[8.1]
  def change
    change_column_null :payouts, :method, true
    change_column_default :payouts, :method, from: "stripe", to: nil
  end
end
