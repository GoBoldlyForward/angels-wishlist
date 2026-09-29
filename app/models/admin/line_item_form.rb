# frozen_string_literal: true

module Admin
  # Staff edit a gift in dollars; the line keeps cents.
  class LineItemForm
    include ActiveModel::Model

    FIELDS = %i[name price spec link_url catalog_item_id].freeze

    attr_accessor(*FIELDS)
    attr_reader :line_item

    def initialize(line_item, attributes = nil)
      @line_item = line_item
      super(current_values.merge((attributes || {}).to_h.symbolize_keys.slice(*FIELDS)))
    end

    def persisted?
      true
    end

    def save
      line_item.assign_attributes(name: name.to_s.strip, price_in_cents: price_in_cents, spec: spec.presence,
                                  link_url: link_url.presence, catalog_item_id: catalog_item_id.presence)
      return true if line_item.save

      line_item.errors.each { |error| errors.add(:base, error.full_message.sub("Price in cents", "Price")) }
      false
    end

    def catalog_items
      chapter_items = CatalogItem.where(organization_id: line_item.wishlist.event.organization_id)
      chapter_items.available.or(chapter_items.where(id: line_item.catalog_item_id)).includes(:category).order(:name)
    end

    private

    def current_values
      { name: line_item.name, price: format("%.2f", line_item.price_in_dollars).delete_suffix(".00"),
        spec: line_item.spec, link_url: line_item.link_url, catalog_item_id: line_item.catalog_item_id }
    end

    def price_in_cents
      (BigDecimal(price.to_s.delete("$, ")) * 100).round
    rescue ArgumentError
      nil
    end
  end
end
