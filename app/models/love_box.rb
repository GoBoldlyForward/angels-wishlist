# frozen_string_literal: true

# One household's Love Box for one event: what the event offers, read against
# what the household picked.
class LoveBox
  Group = Data.define(:id, :label, :options, :picks, :large_household_only, :asks_count, :hint) do
    def self.from(row)
      row = row.to_h.stringify_keys
      new(id: row.fetch("id"), label: row.fetch("label"), options: Array(row["options"]),
          picks: row.fetch("picks", 1).to_i, large_household_only: row["large_household_only"] == true,
          asks_count: row["asks_count"] == true, hint: row["hint"])
    end

    def to_h
      super.stringify_keys
    end
  end

  DECLINED = "No thank you"
  LARGE_HOUSEHOLD_ABOVE = 5

  DEFAULT_GROUPS = [
    { id: "holiday", label: "Holiday celebrated", picks: 1,
      options: [ "Christmas", "Hanukkah", "Kwanzaa", "Winter themed" ] },
    { id: "cups", label: "Festive cups", picks: 1, asks_count: true,
      options: [ "One holiday mug per caregiver", "Holiday plastic cups for each member of the family", DECLINED ] },
    { id: "drink", label: "Family drink", picks: 1,
      options: [ "Hot chocolate", "Apple cider", DECLINED ] },
    { id: "snack", label: "Family snack", picks: 2, hint: "Pick up to two.",
      options: [ "Microwave popcorn (box)", "Boxed candy", DECLINED ] },
    { id: "treat", label: "Family treat", picks: 2, large_household_only: true,
      options: [ "Gingerbread house", "Decorate-a-cookie kit", DECLINED ] },
    { id: "game", label: "Family game", picks: 2, large_household_only: true,
      options: [ "Uno", "Taco Cat Goat Cheese", "Herd Mentality", "Tapple", "Taboo", "Throw Throw Burrito",
                 "Sushi Go!", DECLINED ] },
    { id: "activity", label: "Family activity", picks: 1,
      options: [ "Coloring book for teens and adults, with gel pens", "Coloring book for kids, with crayons",
                 "Family word search book", "Family puzzle", "Family craft kit #1", "Family craft kit #2",
                 DECLINED ] },
    { id: "book", label: "Holiday or winter themed book", picks: 1,
      options: [ "The Snowy Day", "Santa Mouse", "The Polar Express", "The Night Before Christmas", DECLINED ] },
    { id: "grocery", label: "$25 grocery gift card", picks: 1,
      options: [ "Walmart", "Target", "Publix", "ALDI", "Trader Joe's" ] },
    { id: "cozy", label: "Cozy item", picks: 1,
      options: [ "Holiday blanket", "Holiday candle", DECLINED ] },
    { id: "container", label: "Love Box container", picks: 1,
      options: [ "Cloth", "Cardboard, ready to decorate" ] }
  ].map { |row| Group.from(row).to_h }.freeze

  attr_reader :enrollment

  delegate :event, :household, to: :enrollment

  def initialize(enrollment)
    @enrollment = enrollment
  end

  def groups
    event.love_box_groups
  end

  def picks_allowed(group)
    return 1 if group.picks < 2
    return 1 if group.large_household_only && !large_household?

    group.picks
  end

  def picks_for(group)
    Array(enrollment.love_box.dig(group.id, "picks")).compact_blank.first(picks_allowed(group))
  end

  def count_for(group)
    enrollment.love_box.dig(group.id, "count").to_i
  end

  def needs_count?(group)
    group.asks_count && picks_for(group).any? { |pick| pick != DECLINED }
  end

  def summary_for(group)
    picks = picks_for(group)
    return nil if picks.empty?

    needs_count?(group) ? "#{picks.to_sentence} (#{count_for(group)})" : picks.to_sentence
  end

  # Replaces the household's choices with what the form sent, keeping only
  # options the event actually offers.
  def assign(choices)
    choices = choices.to_h.stringify_keys
    enrollment.love_box = groups.to_h do |group|
      row = choices.fetch(group.id, {}).to_h.stringify_keys
      picks = Array(row["picks"]).compact_blank.select { |pick| group.options.include?(pick) }
      [ group.id, { "picks" => picks.uniq.first(picks_allowed(group)), "count" => row["count"].to_i } ]
    end
  end

  def missing_groups
    groups.reject do |group|
      picks_for(group).any? && (!needs_count?(group) || count_for(group).positive?)
    end
  end

  def large_household?
    household.children.active.count > LARGE_HOUSEHOLD_ABOVE
  end

  def complete?
    missing_groups.empty?
  end

  # What volunteers need to pull for the whole event: item => how many.
  def self.totals(event)
    event.enrollments.submitted.includes(household: :children).each_with_object(Hash.new(0)) do |enrollment, totals|
      box = new(enrollment)
      box.groups.each do |group|
        box.picks_for(group).each do |pick|
          next if pick == DECLINED

          totals[[ group.label, pick ]] += box.needs_count?(group) ? box.count_for(group) : 1
        end
      end
    end
  end
end
