# frozen_string_literal: true

module Admin
  module TableHelper
    STATUS_TONES = {
      "verified" => "green", "pending" => "amber", "hold" => "red",
      "live" => "green", "in_review" => "amber", "draft" => "grey", "closed" => "blue", "withdrawn" => "grey",
      "open" => "amber", "funded" => "green", "needs_review" => "violet",
      "succeeded" => "green", "refunded" => "grey", "disputed" => "red", "failed" => "red",
      "scheduled" => "blue", "blocked" => "grey", "held" => "red", "sent" => "green", "delivered" => "green",
      "nomethod" => "amber"
    }.freeze

    STATUS_LABELS = {
      "hold" => "On hold", "in_review" => "In review", "needs_review" => "Needs review",
      "nomethod" => "No method", "held" => "On hold"
    }.freeze

    def status_badge(status, label: nil)
      key = status.to_s
      tag.span(class: [ "status-badge", STATUS_TONES.fetch(key, "grey") ]) do
        tag.span(class: "status-dot") + (label || STATUS_LABELS[key] || key.humanize)
      end
    end

    def stat_card(label, value, icon:, color: "gold", note: nil)
      tag.div(class: "stat-card") do
        tag.div(class: "stat-card-header") do
          tag.span(label, class: "stat-label") + tag.div(tag.i(class: "bi bi-#{icon}"), class: "stat-icon #{color}")
        end + tag.div(value, class: "stat-value") + tag.div(tag.span(note), class: "stat-change flat")
      end
    end

    def progress_cell(percent)
      tone = percent >= 100 ? "" : percent >= 50 ? "part" : "low"
      tag.span(class: "progress-cell") do
        tag.span(tag.i(class: tone, style: "width:#{[ percent, 100 ].min}%"), class: "mini-bar") +
          tag.span("#{percent}%", class: "pct")
      end
    end

    def cell_sub(text)
      tag.span(text, class: "cell-sub")
    end

    def initials_avatar(name)
      tag.span(name.to_s.split.first(2).map(&:first).join.upcase, class: "avatar-sm",
               style: "background: hsl(#{name.to_s.sum % 360} 45% 45%)")
    end

    # pairs is [[label, value], ...]; blank values are left out.
    def key_values(pairs)
      tag.dl(class: "kv") do
        safe_join(pairs.reject { |_label, value| value.blank? }.map { |label, value| tag.dt(label) + tag.dd(value) })
      end
    end

    def detail_section(title, &block)
      tag.div(class: "drawer-section") { tag.h4(title) + capture(&block) }
    end

    def sortable_header(table, key, label, align: nil)
      sort = table.sorts.find { |candidate| candidate.key == key.to_s }
      return tag.th(label, class: ("text-end" if align == :end)) unless sort

      current = table.sort&.key == sort.key
      direction = current && table.direction == "asc" ? "desc" : "asc"
      caret = tag.i(class: "bi bi-caret-#{current && table.direction == 'asc' ? 'up' : 'down'}-fill sort-caret")
      tag.th(class: [ "sortable", ("sorted" if current), ("text-end" if align == :end) ]) do
        link_to(safe_join([ label, caret ]), url_for(table.link_params(sort: sort.key, dir: direction)),
                class: "text-reset text-decoration-none")
      end
    end

    def nav_item(label, path, icon:, count: nil, tone: "secondary")
      active = request.path == path || (path != admin_root_path && request.path.start_with?("#{path}/"))
      link_to path, class: [ "nav-link", ("active" if active) ] do
        badge = count && tag.span(count, class: tone == "danger" ? "badge bg-danger" : "badge bg-secondary bg-opacity-10 text-secondary")
        safe_join([ tag.i(class: "bi bi-#{icon}"), tag.span(label), (badge if count.to_i.positive?) ].compact)
      end
    end
  end
end
