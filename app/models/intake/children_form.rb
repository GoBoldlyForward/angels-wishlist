# frozen_string_literal: true

module Intake
  # Step two: every child in the home, added, changed, and removed together.
  class ChildrenForm
    include ActiveModel::Model

    PERMITTED = [ :id, :legal_first_name, :birthdate, :gender, :caregiver_note, :display_name, :remove,
                  { interests: [] } ].freeze

    attr_reader :household, :event, :entries

    validate :someone_stays
    validate :entries_are_complete
    validate :removals_are_allowed

    def initialize(household:, event:, rows: nil)
      @household = household
      @event = event
      @entries = rows.nil? ? saved_entries : rows.to_h.map { |key, row| entry_from(key, row.to_h.symbolize_keys) }
      add_blank if @entries.empty?
      hand_out_aliases
    end

    def add_blank
      entry = ChildEntry.new(child: Child.new(household: household), event: event)
      entries << entry
      hand_out_aliases
      entry
    end

    def kept
      entries.reject(&:remove)
    end

    def save
      return false unless valid?

      ActiveRecord::Base.transaction do
        entries.select(&:remove).reject(&:new_child?).each { |entry| entry.child.destroy! }
        kept.each(&:save!)
      end
      true
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => e
      errors.add(:base, e.record.errors.full_messages.to_sentence.presence || e.message)
      false
    end

    private

    def saved_entries
      household.children.active.includes(:wishlists).order(:id).map { |child| ChildEntry.new(child: child, event: event) }
    end

    def entry_from(key, row)
      child = row[:id].present? ? household.children.active.find(row[:id]) : Child.new(household: household)
      ChildEntry.new(child: child, event: event, attributes: row.except(:id).merge(key: key.to_s))
    end

    # A new child keeps the stand-in name the caregiver was shown, as long as
    # it is still free.
    def hand_out_aliases
      free = Child::ALIASES - Child.aliases_in_use(household.organization_id)
      entries.select(&:new_child?).each do |entry|
        entry.display_name = free.include?(entry.display_name) ? entry.display_name : free.first
        free.delete(entry.display_name)
      end
    end

    def someone_stays
      errors.add(:base, "Add at least one child.") if kept.empty?
    end

    def entries_are_complete
      errors.add(:base, "Some details are missing below.") unless kept.map(&:valid?).all?
    end

    def removals_are_allowed
      entries.select(&:remove).reject(&:removable?).each do |entry|
        errors.add(:base, "#{entry.child.legal_first_name} has gifts donors already chose, so their list has to stay.")
      end
    end
  end
end
