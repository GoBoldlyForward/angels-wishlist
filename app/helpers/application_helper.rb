module ApplicationHelper
  THEME_STYLESHEETS = %w[theme-angels theme-passion].freeze
  AVATAR_SWATCHES = 6

  def chapter_name
    current_chapter&.name || "Wish List"
  end

  # The chapter's own logo when it has uploaded one, else the one shipped with the app.
  def chapter_mark(**options)
    logo = current_chapter&.logo
    image_tag(logo&.attached? ? logo : bundled_chapter_mark, alt: "", **options)
  end

  def bundled_chapter_mark
    bundled = "chapters/#{current_chapter&.slug}.png"
    Rails.application.assets.load_path.find(bundled) ? bundled : "logo-mark.svg"
  end

  # Whole dollars, the way every figure on the site reads.
  def money(cents)
    number_to_currency(cents.to_i / 100.0, precision: 0)
  end

  def money_exact(cents)
    number_to_currency(cents.to_i / 100.0)
  end

  def theme_stylesheet(organization)
    chosen = organization&.theme&.dig("stylesheet")
    THEME_STYLESHEETS.include?(chosen) ? chosen : THEME_STYLESHEETS.first
  end

  # Token overrides a partner set without shipping a stylesheet of their own.
  def theme_tokens(organization)
    tokens = organization&.theme&.dig("tokens").to_h
    return if tokens.empty?

    rules = tokens.filter_map do |name, value|
      "--#{name.to_s.dasherize}: #{value};" if name.to_s.match?(/\A[a-z0-9_-]+\z/i) && value.to_s.match?(/\A[#\w\s.,%()'-]+\z/)
    end
    tag.style(":root { #{rules.join(' ')} }".html_safe)
  end

  def avatar_swatch(name)
    "var(--av-#{(name.to_s.sum % AVATAR_SWATCHES) + 1})"
  end

  def avatar(name, size: nil)
    tag.span(name.to_s.first, class: [ "avatar", size ], style: "background: #{avatar_swatch(name)}")
  end

  # A gift's picture: an uploaded photo, then the bundled one, then its icon on a tint.
  def gift_art(catalog_item, css_class: "art", icon: nil, tint: nil)
    if catalog_item&.photo&.attached?
      tag.div(image_tag(catalog_item.photo, alt: "", loading: "lazy"), class: "#{css_class} has-photo")
    elsif catalog_item&.stock_photo.present?
      tag.div(image_tag(catalog_item.stock_photo, alt: "", loading: "lazy"), class: "#{css_class} has-photo")
    else
      tag.div(icon || catalog_item&.icon || "🎁", class: [ css_class, tint || catalog_item&.category&.tint || "t1" ])
    end
  end

  def pinpoint_widget
    return if ENV["PINPOINT_EMBED_URL"].blank?

    javascript_include_tag ENV["PINPOINT_EMBED_URL"], async: true
  end

  def test_payments_banner
    return if PaymentGateway.live?

    tag.div("Test mode. No card is collected and nothing is charged.", class: "test-mode-banner")
  end
end
