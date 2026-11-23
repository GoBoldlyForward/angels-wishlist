# frozen_string_literal: true

class AddHeardAboutToDonations < ActiveRecord::Migration[8.1]
  def change
    add_column :donations, :heard_about, :string, limit: 120
  end
end
