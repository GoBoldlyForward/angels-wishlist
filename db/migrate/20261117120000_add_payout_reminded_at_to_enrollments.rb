# frozen_string_literal: true

class AddPayoutRemindedAtToEnrollments < ActiveRecord::Migration[8.1]
  def change
    add_column :enrollments, :payout_reminded_at, :datetime
  end
end
