# frozen_string_literal: true

class SwapLoveBoxAndListsIntakeSteps < ActiveRecord::Migration[8.1]
  # A caregiver on either step has finished the one before it, so the two trade places.
  def up
    swap_steps
  end

  def down
    swap_steps
  end

  private

  def swap_steps
    execute <<~SQL.squish
      UPDATE enrollments
      SET intake_step = CASE intake_step WHEN 'love_box' THEN 'lists' ELSE 'love_box' END
      WHERE intake_step IN ('love_box', 'lists')
    SQL
  end
end
