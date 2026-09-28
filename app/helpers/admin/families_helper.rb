# frozen_string_literal: true

module Admin
  module FamiliesHelper
    PAYOUT_METHOD_LABELS = { "stripe" => "Direct deposit via Stripe", "gift_card" => "Mailed Visa gift card" }.freeze

    # crumbs are labels, or [label, path] pairs for the ones that link somewhere.
    def families_breadcrumbs(*crumbs)
      content_for :breadcrumbs do
        safe_join(crumbs.each_with_index.map do |(label, path), index|
          last = index == crumbs.size - 1
          tag.li(path && !last ? link_to(label, path) : label, class: [ "breadcrumb-item", ("active" if last) ],
                                                               "aria-current": ("page" if last))
        end)
      end
    end

    def family_hero(title, subtitle, lead)
      tag.div(class: "drawer-hero") { lead + tag.div(tag.h3(title) + tag.p(subtitle)) }
    end

    def family_callout(icon:, tone: nil, &block)
      tag.div(class: [ "privacy-note", "mb-3", ("danger" if tone == :danger) ]) do
        tag.i(class: "bi bi-#{icon}") + tag.div(capture(&block))
      end
    end

    def family_form_errors(form)
      return if form.errors.empty?

      tag.div(class: "alert alert-warning", role: "alert") do
        tag.ul(safe_join(form.errors.full_messages.map { |message| tag.li(message) }), class: "mb-0 ps-3")
      end
    end

    def wishlist_badge(wishlist)
      return status_badge("hold", label: "Returned") if wishlist.draft? && wishlist.review_note.present?

      status_badge(wishlist.status)
    end

    def line_item_badge(line_item)
      status_badge(Admin::LineItemsTable.state_of(line_item))
    end

    def payout_badge(status, event)
      return status_badge(status) unless status.to_s == "scheduled" && event&.payout_at

      status_badge(status, label: "Scheduled #{event.payout_at.strftime('%b %-d')}")
    end

    def payout_method_label(household)
      PAYOUT_METHOD_LABELS[household.payout_method] || tag.span("Not set up", class: "text-danger")
    end

    def payout_destination(household)
      return household.stripe_account_id.presence || "Stripe onboarding not finished" if household.payout_via_stripe?
      return household.mailing_address&.to_s.presence || "No mailing address" if household.payout_via_gift_card?

      "No destination"
    end

    def child_label(child)
      child.age ? "#{child.display_name}, #{child.age}" : child.display_name
    end

    def gift_thumb(catalog_item)
      if catalog_item&.photo&.attached?
        image_tag(catalog_item.photo, class: "thumb", alt: "", loading: "lazy")
      elsif catalog_item&.stock_photo.present?
        image_tag(catalog_item.stock_photo, class: "thumb", alt: "", loading: "lazy")
      else
        tag.span(catalog_item&.icon.presence || "🎁", class: "thumb-emoji")
      end
    end

    def link_host(url)
      URI.parse(url).host.to_s.delete_prefix("www.").presence || url
    rescue URI::InvalidURIError
      url
    end

    def date_or_not_yet(time)
      time ? l(time.to_date, format: :long) : tag.span("not yet", class: "text-muted")
    end

    def ago_or_dash(time)
      time ? "#{time_ago_in_words(time)} ago" : tag.span("—", class: "text-muted")
    end

    def muted_dash(text = "—")
      tag.span(text, class: "text-muted")
    end

    VERSION_EVENTS = { "create" => [ "live", "Created" ], "update" => [ "scheduled", "Changed" ],
                       "destroy" => [ "failed", "Removed" ] }.freeze

    def version_event_badge(version)
      tone, label = VERSION_EVENTS.fetch(version.event, [ "draft", version.event.humanize ])
      status_badge(tone, label: label)
    end

    # One change as staff read it: "field: before → after".
    def changeset_line(field, before, after)
      tag.div(class: "change-line") do
        tag.span("#{field.humanize}: ", class: "text-muted") + change_value(before) + " → " + change_value(after)
      end
    end

    def change_value(value)
      case value
      when nil, "" then tag.span("nothing", class: "text-muted")
      when Time, ActiveSupport::TimeWithZone then l(value, format: :short)
      when /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/ then l(Time.zone.parse(value), format: :short)
      when Hash, Array then value.empty? ? tag.span("nothing", class: "text-muted") : truncate(value.to_json, length: 140)
      else truncate(value.to_s, length: 140)
      end
    end
  end
end
