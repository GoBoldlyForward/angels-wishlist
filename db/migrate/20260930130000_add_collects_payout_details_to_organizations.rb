# frozen_string_literal: true

class AddCollectsPayoutDetailsToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :collects_payout_details, :boolean, default: true, null: false
  end
end
