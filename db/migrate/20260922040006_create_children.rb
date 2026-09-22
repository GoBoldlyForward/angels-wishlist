# frozen_string_literal: true

class CreateChildren < ActiveRecord::Migration[8.1]
  def change
    create_table :children do |t|
      t.references :household, null: false, foreign_key: true

      # The legal name never leaves staff and the child's own caregiver.
      # The alias is what a donor sees, and it is assigned by the system.
      t.string :legal_first_name
      t.string :alias, null: false
      t.date   :birthdate
      t.string :gender

      t.datetime :archived_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :children, :deleted_at
  end
end
