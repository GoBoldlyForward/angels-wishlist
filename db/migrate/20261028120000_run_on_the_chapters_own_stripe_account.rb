# frozen_string_literal: true

class RunOnTheChaptersOwnStripeAccount < ActiveRecord::Migration[8.1]
  def change
    remove_column :organizations, :stripe_account_id, :string
    remove_column :organizations, :stripe_charges_enabled, :boolean, default: false, null: false
    remove_column :organizations, :platform_fee_basis_points, :integer, default: 0, null: false
    remove_column :donations, :platform_fee_in_cents, :integer, default: 0, null: false
    remove_column :payouts, :stripe_debit_id, :string
    remove_column :payouts, :debited_in_cents, :integer
  end
end
