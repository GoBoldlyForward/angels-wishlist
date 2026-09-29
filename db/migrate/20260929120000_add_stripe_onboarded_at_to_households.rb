# frozen_string_literal: true

class AddStripeOnboardedAtToHouseholds < ActiveRecord::Migration[8.1]
  def up
    add_column :households, :stripe_onboarded_at, :datetime

    # Every account so far was made in test mode, which finishes onboarding at once.
    execute "UPDATE households SET stripe_onboarded_at = updated_at WHERE stripe_account_id IS NOT NULL"
  end

  def down
    remove_column :households, :stripe_onboarded_at
  end
end
