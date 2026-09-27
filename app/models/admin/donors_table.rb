# frozen_string_literal: true

module Admin
  # Everyone who gave to one event, one row per giver, with their season added up.
  class DonorsTable < Table
    SUCCEEDED = "FILTER (WHERE donations.status = 'succeeded')"
    GIFTS_CHOSEN = "SELECT COUNT(*) FROM line_items WHERE line_items.donation_id = donations.id " \
                   "AND line_items.deleted_at IS NULL"

    CSV_COLUMNS = {
      "Donor" => ->(row) { row.full_name },
      "Email" => ->(row) { row.email },
      "Type" => ->(row) { DonorType.of(row).label },
      "Shown as" => ->(row) { row.gives_anonymously ? "Anonymous" : row.shown_as.presence || row.full_name },
      "Donations" => ->(row) { row.donations_count },
      "Gifts chosen" => ->(row) { row.gifts_count },
      "Given" => ->(row) { Dollars.from_cents(row.given_in_cents) },
      "Card fees covered" => ->(row) { Dollars.from_cents(row.fees_in_cents) },
      "Last gave" => ->(row) { row.last_gave_at.to_date }
    }.freeze

    attr_reader :event

    def initialize(event, params)
      @event = event
      super(donors, params, tabs: donor_tabs, filters: donor_filters, sorts: donor_sorts,
            search: method(:matching), default_order: Arel.sql("giving.given_in_cents DESC, users.id"))
    end

    def rows
      super.select("users.*", "giving.*")
    end

    def donor_count
      @donor_count ||= donors.count
    end

    def anonymous_count
      donors.where("giving.gives_anonymously").count
    end

    def group_count
      groups.count
    end

    def group_given_in_cents
      groups.sum("giving.given_in_cents").to_i
    end

    def average_gift_in_cents
      succeeded_count.zero? ? 0 : event.raised_in_cents / succeeded_count
    end

    def fees_in_cents
      event.donations.succeeded.sum(:fee_in_cents)
    end

    def fee_covered_percent
      return 0 if succeeded_count.zero?

      (event.donations.succeeded.where("fee_in_cents > 0").count * 100.0 / succeeded_count).round
    end

    private

    def donors
      User.joins("INNER JOIN (#{giving.to_sql}) giving ON giving.donor_id = users.id")
    end

    def groups
      DonorType.narrow(donors, "group")
    end

    def succeeded_count
      @succeeded_count ||= event.donations.succeeded.count
    end

    def giving
      event.donations.group(:donor_id).select(
        "donations.donor_id",
        "COUNT(*) AS donations_count",
        "COALESCE(SUM(donations.gift_in_cents + donations.general_gift_in_cents) #{SUCCEEDED}, 0) AS given_in_cents",
        "COALESCE(SUM(donations.fee_in_cents) #{SUCCEEDED}, 0) AS fees_in_cents",
        "COALESCE(SUM((#{GIFTS_CHOSEN})), 0)::integer AS gifts_count",
        "BOOL_OR(donations.anonymous) AS gives_anonymously",
        "MAX(donations.created_at) AS last_gave_at",
        "(ARRAY_AGG(donations.display_name ORDER BY donations.created_at DESC))[1] AS shown_as"
      )
    end

    def donor_tabs
      [
        Tab.new(key: "all", label: "All"),
        Tab.new(key: "individuals", label: "Individuals", scope: ->(rows) { DonorType.narrow(rows, "individual") }),
        Tab.new(key: "families", label: "Families", scope: ->(rows) { DonorType.narrow(rows, "family") }),
        Tab.new(key: "groups", label: "Groups & teams", scope: ->(rows) { DonorType.narrow(rows, "group") }),
        Tab.new(key: "anonymous", label: "Anonymous", scope: ->(rows) { rows.where("giving.gives_anonymously") }),
        Tab.new(key: "repeat", label: "Gave more than once",
                scope: ->(rows) { rows.where("giving.donations_count > 1") })
      ]
    end

    def donor_filters
      [
        Filter.new(key: "shown", label: "Shown as", options: { "Their name" => "named", "Anonymous" => "anonymous" },
                   scope: ->(rows, value) { rows.where("giving.gives_anonymously = ?", value == "anonymous") }),
        Filter.new(key: "fee", label: "Card fee", options: { "Covered" => "covered", "Not covered" => "none" },
                   scope: ->(rows, value) { rows.where("giving.fees_in_cents #{value == 'covered' ? '>' : '='} 0") }),
        Filter.new(key: "chose", label: "Gave to",
                   options: { "Chosen gifts" => "gifts", "General giving only" => "general" },
                   scope: ->(rows, value) { rows.where("giving.gifts_count #{value == 'gifts' ? '>' : '='} 0") })
      ]
    end

    def donor_sorts
      [
        Sort.new(key: "name", label: "Name", order: DonorType::NAME_SQL),
        Sort.new(key: "donations", label: "Donations", order: "giving.donations_count"),
        Sort.new(key: "gifts", label: "Gifts chosen", order: "giving.gifts_count"),
        Sort.new(key: "given", label: "Given", order: "giving.given_in_cents"),
        Sort.new(key: "last", label: "Last gave", order: "giving.last_gave_at")
      ]
    end

    def matching(rows, query)
      like = "%#{User.sanitize_sql_like(query)}%"
      rows.where("#{DonorType::NAME_SQL} ILIKE :like OR users.email ILIKE :like OR giving.shown_as ILIKE :like",
                 like: like)
    end
  end
end
