# frozen_string_literal: true

class RenameGroceryGiftCardGroup < ActiveRecord::Migration[8.1]
  OLD_LABEL = "$25 grocery gift card"
  NEW_LABEL = "Your preferred grocery store"

  def up
    relabel(OLD_LABEL, NEW_LABEL)
  end

  def down
    relabel(NEW_LABEL, OLD_LABEL)
  end

  private

  def relabel(from, to)
    select_rows("SELECT id, love_box_options FROM events").each do |id, options|
      groups = options.is_a?(String) ? JSON.parse(options) : options
      groups.each { |group| group["label"] = to if group["id"] == "grocery" && group["label"] == from }
      update "UPDATE events SET love_box_options = #{quote(groups.to_json)} WHERE id = #{quote(id)}"
    end
  end
end
