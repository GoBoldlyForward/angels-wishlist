# frozen_string_literal: true

class AddLoveBoxOptionsToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :love_box_options, :jsonb, null: false, default: []
  end
end
