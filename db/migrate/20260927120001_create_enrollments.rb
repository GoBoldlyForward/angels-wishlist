# frozen_string_literal: true

class CreateEnrollments < ActiveRecord::Migration[8.1]
  def change
    create_table :enrollments do |t|
      t.references :household, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true

      t.datetime :spending_agreed_at
      # One entry per Love Box group: { "snack" => { "picks" => [...], "count" => 4 } }
      t.jsonb    :love_box, null: false, default: {}
      t.string   :intake_step, null: false, default: "home"
      t.datetime :submitted_at

      t.datetime :deleted_at
      t.timestamps
    end

    add_index :enrollments, %i[household_id event_id], unique: true
    add_index :enrollments, :deleted_at
  end
end
