# frozen_string_literal: true

require "csv"

module Admin
  # What volunteers need to assemble the Love Boxes for one event: a total
  # per item, then each submitted household's box.
  class PackingList
    Box = Data.define(:household, :children_count, :selection)

    attr_reader :event

    def initialize(event)
      @event = event
    end

    def groups
      event ? event.love_box_groups : []
    end

    # { group label => { item => how many } }, in the order the event lists its groups.
    def totals
      @totals ||= begin
        counted = event ? LoveBox.totals(event) : {}
        groups.to_h { |group| [ group.label, counted.select { |(label, _item), _count| label == group.label }
                                                    .transform_keys(&:last) ] }
              .reject { |_label, items| items.empty? }
      end
    end

    def boxes
      @boxes ||= begin
        submitted = enrollments.to_a
        children = Child.active.where(household_id: submitted.map(&:household_id)).group(:household_id).count
        submitted.map do |enrollment|
          Box.new(household: enrollment.household, children_count: children.fetch(enrollment.household_id, 0),
                  selection: enrollment.love_box_selection)
        end
      end
    end

    # columns maps a header to what goes under it, as Admin::Table#to_csv does.
    def to_csv(columns = csv_columns)
      CSV.generate do |csv|
        csv << columns.keys
        boxes.each { |box| csv << columns.values.map { |value| value.call(box) } }
      end
    end

    def totals_csv
      CSV.generate do |csv|
        csv << [ "Group", "Item", "How many" ]
        totals.each { |label, items| items.each { |item, count| csv << [ label, item, count ] } }
      end
    end

    def csv_columns
      {
        "Household" => ->(box) { box.household.display_name },
        "Caregiver" => ->(box) { box.household.caregiver&.full_name },
        "County" => ->(box) { box.household.county },
        "Children" => ->(box) { box.children_count },
        "Verified" => ->(box) { box.household.verification_verified? ? "yes" : "no" }
      }.merge(groups.to_h { |group| [ group.label, ->(box) { box.selection.summary_for(group) } ] })
    end

    private

    def enrollments
      return Enrollment.none unless event

      event.enrollments.submitted.joins(:household).preload(household: :caregiver)
           .order("households.display_name", :id)
    end
  end
end
