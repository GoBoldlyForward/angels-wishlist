# frozen_string_literal: true

class CreateHouseholds < ActiveRecord::Migration[8.1]
  def change
    create_table :households do |t|
      t.references :organization, null: false, foreign_key: true
      # The agency that placed the children. Recorded by staff at verification,
      # so it is null for a household that has only signed up.
      t.references :placing_organization, foreign_key: { to_table: :organizations }
      t.references :caregiver, null: false, foreign_key: { to_table: :users }
      t.references :mailing_address, foreign_key: { to_table: :addresses }
      t.bigint     :ahoy_visit_id

      t.string :display_name, null: false
      t.string :county

      t.string   :verification_status, null: false, default: "pending"
      t.datetime :verified_at
      t.text     :hold_reason

      t.string :payout_method, null: false, default: "none"
      t.string :stripe_account_id

      t.string   :slug
      t.datetime :archived_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :households, :slug, unique: true
    add_index :households, :verification_status
    add_index :households, :ahoy_visit_id
    add_index :households, :deleted_at
  end
end
