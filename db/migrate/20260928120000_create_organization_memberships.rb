# frozen_string_literal: true

class CreateOrganizationMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true

      t.datetime :deleted_at

      t.timestamps
    end

    # Revoking access soft-deletes the row, so the pair has to be free again
    # for the same person to be added back later.
    add_index :organization_memberships, %i[user_id organization_id], unique: true,
              where: "deleted_at IS NULL"
    add_index :organization_memberships, :deleted_at
  end
end
