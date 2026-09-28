# frozen_string_literal: true

module Admin
  class EventForm < RecordForm
    PASSED_THROUGH = %w[name opened_at closes_at payout_at].freeze
    DEFAULT_CAP_IN_CENTS = 20_000

    delegate :name, :opened_at, :closes_at, :payout_at, to: :record

    def self.for_new_event(organization, params = {})
      new(Event.new(organization: organization, per_child_cap_in_cents: DEFAULT_CAP_IN_CENTS,
                    love_box_options: LoveBox::DEFAULT_GROUPS), params)
    end

    def per_child_cap_in_dollars
      @params[:per_child_cap_in_dollars] || Dollars.from_cents(record.per_child_cap_in_cents)
    end

    def love_box_groups
      record.love_box_groups
    end

    # Lists already asking for more than the cap. They keep their gifts and cannot take another.
    def lists_over_the_cap
      asked_by_list.count { |cents| cents > record.per_child_cap_in_cents.to_i }
    end

    def largest_list_in_cents
      asked_by_list.max.to_i
    end

    def cap_warning
      over = lists_over_the_cap
      return if over.zero?

      "#{over} #{over == 1 ? 'list already asks' : 'lists already ask'} for more than the cap. " \
        "They keep their gifts and cannot take another."
    end

    private

    def assign
      super
      cap = @params[:per_child_cap_in_dollars]
      record.per_child_cap_in_cents = Dollars.to_cents(cap).to_i if cap
      record.love_box_options = groups_from(@params[:love_box_groups]) if @params.key?(:love_box_edited)
    end

    def check
      errors.add(:base, "The cap per child must be a dollar amount above zero") unless record.per_child_cap_in_cents.positive?
      love_box_groups.each do |group|
        errors.add(:base, "#{group.label} needs at least one option") if group.options.empty?
      end
    end

    def asked_by_list
      return [] if record.new_record?

      @asked_by_list ||= LineItem.listed.where(wishlist_id: record.wishlists.where.not(status: "withdrawn").select(:id))
                                 .group(:wishlist_id).sum(:price_in_cents).values
    end

    def groups_from(rows)
      taken = []
      rows.to_h.values.filter_map do |row|
        next if row[:label].blank?

        options = row[:options].to_s.lines.map(&:strip).compact_blank.uniq
        LoveBox::Group.from(
          id: unique_id(row[:id].presence || row[:label], taken), label: row[:label].strip, options: options,
          picks: row[:picks].to_i.clamp(1, [ options.size, 1 ].max), hint: row[:hint].presence,
          large_household_only: row[:large_household_only] == "1", asks_count: row[:asks_count] == "1"
        ).to_h
      end
    end

    def unique_id(wanted, taken)
      base = wanted.to_s.parameterize(separator: "_").presence || "group"
      id = base
      suffix = 1
      id = "#{base}_#{suffix += 1}" while taken.include?(id)
      taken << id
      id
    end
  end
end
