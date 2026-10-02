# frozen_string_literal: true

# Every Love Box comes in a decorated cardboard box, and the two craft kits are
# one choice a household may pick alongside another activity.
class OfferOneCraftKitAndNoLoveBoxContainer < ActiveRecord::Migration[8.1]
  CRAFT_KIT = "Family craft kit"
  CRAFT_KITS = [ "Family craft kit #1", "Family craft kit #2" ].freeze

  def up
    select_rows("SELECT id, love_box_options FROM events").each do |id, options|
      groups = parse(options).reject { |group| group["id"] == "container" }
      groups.each do |group|
        next unless group["id"] == "activity"

        group["options"] = group["options"].map { |option| CRAFT_KITS.include?(option) ? CRAFT_KIT : option }.uniq
        group["picks"] = 2
        group["hint"] = "Pick up to two."
      end
      update "UPDATE events SET love_box_options = #{quote(groups.to_json)} WHERE id = #{quote(id)}"
    end

    select_rows("SELECT id, love_box FROM enrollments").each do |id, box|
      choices = parse(box)
      choices.delete("container")
      if (activity = choices["activity"])
        activity["picks"] = Array(activity["picks"]).map { |pick| CRAFT_KITS.include?(pick) ? CRAFT_KIT : pick }.uniq
      end
      update "UPDATE enrollments SET love_box = #{quote(choices.to_json)} WHERE id = #{quote(id)}"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def parse(json)
    json.is_a?(String) ? JSON.parse(json) : json
  end
end
