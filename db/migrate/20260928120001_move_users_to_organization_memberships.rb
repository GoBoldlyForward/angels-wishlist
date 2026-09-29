# frozen_string_literal: true

class MoveUsersToOrganizationMemberships < ActiveRecord::Migration[8.1]
  def up
    # Only live chapter staff carry access across. A rollback leaves these rows
    # in place, so running this again must skip the pairs already present.
    execute <<~SQL.squish
      INSERT INTO organization_memberships (user_id, organization_id, created_at, updated_at)
      SELECT id, organization_id, NOW(), NOW() FROM users
      WHERE organization_id IS NOT NULL AND role = 'staff' AND deleted_at IS NULL
      ON CONFLICT (user_id, organization_id) WHERE deleted_at IS NULL DO NOTHING
    SQL

    execute "UPDATE users SET role = 'admin' WHERE role = 'staff' AND is_admin = TRUE"
    execute "UPDATE users SET role = 'organizer' WHERE role = 'staff'"

    remove_column :users, :is_admin
    remove_reference :users, :organization, foreign_key: true
  end

  def down
    add_reference :users, :organization, foreign_key: true
    add_column :users, :is_admin, :boolean, null: false, default: false

    execute "UPDATE users SET is_admin = TRUE WHERE role = 'admin'"
    execute "UPDATE users SET role = 'staff' WHERE role IN ('organizer', 'admin')"

    # A user with several memberships had one organization before this, and
    # there is no record of which. The oldest live membership is the closest guess.
    execute <<~SQL.squish
      UPDATE users SET organization_id = (
        SELECT organization_id FROM organization_memberships
        WHERE organization_memberships.user_id = users.id
          AND organization_memberships.deleted_at IS NULL
        ORDER BY organization_memberships.id LIMIT 1
      )
    SQL
  end
end
