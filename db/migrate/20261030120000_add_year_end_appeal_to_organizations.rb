# frozen_string_literal: true

class AddYearEndAppealToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :year_end_appeal, :jsonb, default: {}, null: false
  end
end
