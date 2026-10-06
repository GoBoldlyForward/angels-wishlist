# frozen_string_literal: true

module Caregiver
  module IntakeHelper
    STEP_LABELS = { "home" => "Your home", "children" => "The children", "lists" => "Their lists",
                    "love_box" => "Love Box", "payout" => "Getting paid", "review" => "Review" }.freeze

    def event_day(time)
      time&.in_time_zone&.strftime("%B %-d")
    end

    def field_error(record, attribute)
      message = record.errors.full_messages_for(attribute).first
      tag.p("#{message}.", class: "field-error") if message
    end

    def input_class(record, attribute)
      class_names("i", "is-invalid": record.errors[attribute].any?)
    end

    def link_host(url)
      URI.parse(url).host.to_s.delete_prefix("www.").presence || "the link"
    rescue URI::InvalidURIError
      "the link"
    end

    def listed_gifts(wishlist)
      wishlist.line_items.select(&:persisted?).reject(&:withdrawn_status?).sort_by(&:id)
    end

    def gifts_total_in_cents(wishlist)
      listed_gifts(wishlist).sum(&:price_in_cents)
    end

    def donor_facts(wishlist, household)
      child = wishlist.child
      [ child.display_name, child.age, child.gender, ("#{household.county} County" if household.county.present?),
        *(wishlist.interests.presence || [ "no interests listed" ]),
        ("your sentence about them" if wishlist.caregiver_note.present?), "these gifts" ].compact.to_sentence
    end

    def payout_summary(household)
      if household.payout_via_stripe?
        "Bank account or debit card, through Stripe"
      elsif household.payout_via_gift_card?
        "Visa gift card emailed to #{household.gift_card_email}"
      else
        "Not chosen yet"
      end
    end
  end
end
