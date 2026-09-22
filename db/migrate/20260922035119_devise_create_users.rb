# frozen_string_literal: true

class DeviseCreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      ## Profile
      t.string :first_name
      t.string :last_name
      t.string :phone
      t.string :preferred_language

      ## A donor created at checkout has no password until they choose one,
      ## which is what lets guest giving and a returning donor share a row.
      t.string  :role, null: false, default: "donor"
      t.boolean :is_admin, null: false, default: false

      t.string   :slug
      t.uuid     :uuid, null: false, default: -> { "gen_random_uuid()" }
      t.bigint   :ahoy_visit_id
      t.datetime :deleted_at

      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :slug,                 unique: true
    add_index :users, :uuid,                 unique: true
    add_index :users, :role
    add_index :users, :ahoy_visit_id
    add_index :users, :deleted_at
  end
end
