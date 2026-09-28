# frozen_string_literal: true

module Storefront
  # One gift a child asked for, as a donor sees it.
  class Gift
    KEY_PURPOSE = :storefront_gift
    CUSTOM_SEPARATOR = "--"

    attr_reader :key, :name, :spec, :price_in_cents, :link_url, :catalog_item, :category, :child, :chosen_by,
                :waiting_order

    def initialize(line, child:, in_cart: false)
      @key = line.signed_id(purpose: KEY_PURPOSE)
      @name = line.name
      @spec = line.spec.presence
      @price_in_cents = line.price_in_cents
      @link_url = line.link_url if line.link_url.to_s.match?(%r{\Ahttps?://}i)
      @catalog_item = line.catalog_item
      @category = @catalog_item&.category
      @child = child
      @funded = line.funded?
      @chosen_by = Gift.public_name(line.donation) if @funded
      @in_cart = in_cart
      @waiting_order = [ line.created_at, line.id ]
    end

    # Lines sharing a catalog item share a tile. A custom line is a tile of its own.
    def product_key
      catalog_item&.slug || [ child.key, name.parameterize.presence || "gift" ].join(CUSTOM_SEPARATOR)
    end

    def product_name
      catalog_item&.name || name
    end

    def link_host
      URI.parse(link_url).host.to_s.delete_prefix("www.").presence || "the link"
    rescue URI::InvalidURIError
      "the link"
    end

    def funded?
      @funded
    end

    def in_cart?
      @in_cart && !funded?
    end

    def available?
      !funded? && !in_cart?
    end

    def pooled?
      spec.blank?
    end

    # A donor's account name or email never stands in for a name they did not give.
    def self.public_name(donation)
      donation.anonymous? || donation.display_name.blank? ? "Anonymous" : donation.display_name
    end

    def self.find_line(key)
      LineItem.find_signed(key.to_s, purpose: KEY_PURPOSE)
    end
  end
end
