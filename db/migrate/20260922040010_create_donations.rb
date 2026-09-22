# frozen_string_literal: true

class CreateDonations < ActiveRecord::Migration[8.1]
  def change
    create_table :donations do |t|
      t.references :donor, null: false, foreign_key: { to_table: :users }
      t.references :event, null: false, foreign_key: true
      # Which storefront skin the gift came through. The money still settles
      # to the event's own organization.
      t.references :storefront_organization, foreign_key: { to_table: :organizations }
      t.bigint     :ahoy_visit_id

      t.string :stripe_payment_intent_id
      t.string :payment_method_label

      t.integer :gift_in_cents, null: false, default: 0
      t.integer :general_gift_in_cents, null: false, default: 0
      t.integer :fee_in_cents, null: false, default: 0

      t.string :status, null: false, default: "pending"

      t.string  :display_name
      t.boolean :anonymous, null: false, default: false

      t.text     :note_to_family
      t.datetime :note_approved_at
      t.datetime :receipt_sent_at

      t.uuid     :uuid, null: false, default: -> { "gen_random_uuid()" }
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :donations, :uuid, unique: true
    add_index :donations, :stripe_payment_intent_id, unique: true
    add_index :donations, :status
    add_index :donations, :ahoy_visit_id
    add_index :donations, :deleted_at
  end
end
