# frozen_string_literal: true

module Admin
  # The ledger for one event, one row per donation.
  class DonationsTable < Table
    CHARGED = "(donations.gift_in_cents + donations.general_gift_in_cents + donations.fee_in_cents)"
    GIVEN = "(donations.gift_in_cents + donations.general_gift_in_cents)"

    CSV_COLUMNS = {
      "Reference" => ->(row) { row.uuid.first(8) },
      "Date" => ->(row) { row.created_at.to_date },
      "Donor" => ->(row) { row.donor.full_name },
      "Email" => ->(row) { row.donor.email },
      "Shown as" => ->(row) { row.public_display_name },
      "What they chose" => ->(row) { DonationChoice.new(row).to_s },
      "Chosen gifts" => ->(row) { Dollars.from_cents(row.gift_in_cents) },
      "General gift" => ->(row) { Dollars.from_cents(row.general_gift_in_cents) },
      "Fee" => ->(row) { Dollars.from_cents(row.fee_in_cents) },
      "Charged" => ->(row) { Dollars.from_cents(row.charged_in_cents) },
      "Method" => ->(row) { row.payment_method_label },
      "Status" => ->(row) { row.status }
    }.freeze

    attr_reader :event

    def initialize(event, params)
      @event = event
      super(ledger, params, tabs: ledger_tabs, filters: ledger_filters, sorts: ledger_sorts,
            search: method(:matching), default_order: { created_at: :desc, id: :desc })
    end

    def succeeded_count
      totals.dig("succeeded", :count).to_i
    end

    def chosen_in_cents
      totals.dig("succeeded", :gift).to_i
    end

    def general_in_cents
      totals.dig("succeeded", :general).to_i
    end

    def fees_in_cents
      totals.dig("succeeded", :fee).to_i
    end

    def raised_in_cents
      chosen_in_cents + general_in_cents
    end

    def count_of(*statuses)
      statuses.sum { |status| totals.dig(status.to_s, :count).to_i }
    end

    private

    def ledger
      event.donations.joins(:donor).preload(:donor, line_items: { wishlist: :child })
    end

    def totals
      @totals ||= event.donations.group(:status)
                       .pluck(:status, Arel.sql("COUNT(*)"), Arel.sql("SUM(gift_in_cents)"),
                              Arel.sql("SUM(general_gift_in_cents)"), Arel.sql("SUM(fee_in_cents)"))
                       .to_h { |status, count, gift, general, fee| [ status, { count:, gift:, general:, fee: } ] }
    end

    def ledger_tabs
      [
        Tab.new(key: "all", label: "All"),
        Tab.new(key: "succeeded", label: "Succeeded", scope: ->(rows) { rows.succeeded }),
        Tab.new(key: "pending", label: "Pending", scope: ->(rows) { rows.pending }),
        Tab.new(key: "disputed", label: "Disputed", scope: ->(rows) { rows.disputed }, tone: "danger"),
        Tab.new(key: "refunded", label: "Refunded", scope: ->(rows) { rows.refunded }),
        Tab.new(key: "general", label: "General giving",
                scope: ->(rows) { rows.where("donations.general_gift_in_cents > 0") }),
        Tab.new(key: "offline", label: "Offline", scope: ->(rows) { rows.offline })
      ]
    end

    def ledger_filters
      [
        Filter.new(key: "method", label: "Method", options: methods_in_use,
                   scope: ->(rows, value) { rows.where(payment_method_label: value) }),
        Filter.new(key: "fee", label: "Card fee", options: { "Covered" => "covered", "Not covered" => "none" },
                   scope: ->(rows, value) { rows.where("donations.fee_in_cents #{value == 'covered' ? '>' : '='} 0") }),
        Filter.new(key: "shown", label: "Shown as", options: { "Their name" => "named", "Anonymous" => "anonymous" },
                   scope: ->(rows, value) { rows.where(anonymous: value == "anonymous") }),
        Filter.new(key: "note", label: "Note to the family",
                   options: { "Awaiting approval" => "waiting", "Approved" => "approved" },
                   scope: ->(rows, value) { value == "waiting" ? rows.with_unapproved_note : rows.where.not(note_approved_at: nil) })
      ]
    end

    def methods_in_use
      event.donations.where.not(payment_method_label: [ nil, "" ]).distinct.order(:payment_method_label)
           .pluck(:payment_method_label).index_with(&:itself)
    end

    def ledger_sorts
      [
        Sort.new(key: "date", label: "Date", order: "donations.created_at"),
        Sort.new(key: "donor", label: "Donor", order: DonorType::NAME_SQL),
        Sort.new(key: "gift", label: "Gift", order: GIVEN),
        Sort.new(key: "fee", label: "Fee", order: "donations.fee_in_cents"),
        Sort.new(key: "charged", label: "Charged", order: CHARGED),
        Sort.new(key: "method", label: "Method", order: "donations.payment_method_label"),
        Sort.new(key: "status", label: "Status", order: "donations.status")
      ]
    end

    def matching(rows, query)
      like = "%#{Donation.sanitize_sql_like(query)}%"
      rows.where("donations.uuid::text ILIKE :like OR #{DonorType::NAME_SQL} ILIKE :like OR users.email ILIKE :like " \
                 "OR donations.display_name ILIKE :like", like: like)
    end
  end
end
