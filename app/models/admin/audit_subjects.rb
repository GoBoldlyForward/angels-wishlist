# frozen_string_literal: true

module Admin
  # Names the record behind each version on a page of the audit trail, and
  # which staff page shows it, loading each kind of record once.
  class AuditSubjects
    Subject = Data.define(:kind, :label, :page)

    # page is the record whose staff page a version links to; nil when it has none.
    KINDS = {
      "Household" => { load: -> { Household.with_deleted },
                       label: ->(record) { record.display_name }, page: ->(record) { record } },
      "Wishlist" => { load: -> { Wishlist.with_deleted.preload(:child) },
                      label: ->(record) { "#{record.child&.display_name || 'A child'}'s list" },
                      page: ->(record) { record } },
      "LineItem" => { load: -> { LineItem.with_deleted },
                      label: ->(record) { record.name }, page: ->(record) { record } },
      "Donation" => { load: -> { Donation.with_deleted },
                      label: ->(record) { "Donation #{record.uuid.first(8)}" }, page: ->(record) { record } },
      "Payout" => { load: -> { Payout.with_deleted.preload(:household) },
                    label: ->(record) { "Payout to #{record.household&.display_name || 'a household'}" },
                    page: ->(record) { record } },
      "Enrollment" => { load: -> { Enrollment.with_deleted.preload(:household) },
                        label: ->(record) { "#{record.household&.display_name || 'A household'}'s enrollment" },
                        page: ->(record) { record.household } }
    }.freeze

    def initialize(versions)
      @versions = versions.to_a
    end

    def for(version)
      kind = version.item_type.underscore.humanize
      record = records.dig(version.item_type, version.item_id)
      rules = KINDS[version.item_type]
      return Subject.new(kind: kind, label: "##{version.item_id}", page: nil) unless record && rules

      Subject.new(kind: kind, label: rules[:label].call(record),
                  page: record.deleted? ? nil : rules[:page].call(record))
    end

    private

    def records
      @records ||= @versions.group_by(&:item_type).slice(*KINDS.keys).to_h do |type, versions|
        [ type, KINDS.dig(type, :load).call.where(id: versions.map(&:item_id).uniq).index_by(&:id) ]
      end
    end
  end
end
