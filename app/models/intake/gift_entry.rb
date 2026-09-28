# frozen_string_literal: true

module Intake
  # What a caregiver typed for one gift, tidied into what Wishlist#add_gift takes.
  class GiftEntry
    BARE_DOMAIN = %r{\A[\w-]+(\.[\w-]+)+(/.*)?\z}
    SUBJECTS = { price_in_cents: "That price", name: "The name", link_url: "The link" }.freeze

    attr_reader :name, :price, :link, :line_item

    def initialize(name: nil, price: nil, link: nil)
      @name = name.to_s.strip
      @price = price.to_s.strip
      @link = link.to_s.strip
    end

    def price_in_cents
      (BigDecimal(price.delete("$,")) * 100).round
    rescue ArgumentError
      0
    end

    # Caregivers paste whatever the browser gave them, so a bare domain is
    # accepted and anything that is not a link is dropped.
    def link_url
      return link if link.match?(%r{\Ahttps?://}i)

      "https://#{link}" if link.match?(BARE_DOMAIN)
    end

    def add_to(wishlist)
      @line_item = wishlist.add_gift(name: name, price_in_cents: price_in_cents, link_url: link_url)
      line_item.persisted?
    end

    def refusal
      return nil if line_item.nil? || line_item.errors.empty?

      line_item.errors.map { |error| "#{SUBJECTS.fetch(error.attribute, 'This gift')} #{error.message}." }.join(" ")
    end
  end
end
