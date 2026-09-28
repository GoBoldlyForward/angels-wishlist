# frozen_string_literal: true

module Admin
  class CatalogItemForm < RecordForm
    PASSED_THROUGH = %w[name category_id min_age max_age icon active photo_attribution].freeze

    attr_reader :photo_error

    delegate :name, :category_id, :min_age, :max_age, :icon, :active, :photo_attribution, :photo, :stock_photo,
             to: :record

    def price_in_dollars
      @params[:price_in_dollars] || Dollars.from_cents(record.price_in_cents)
    end

    # The item is saved first, so a photo that cannot be stored never loses the rest of the form.
    def save
      return false unless super

      attach_photo if @params[:photo].present?
      true
    end

    private

    def assign
      super
      record.price_in_cents = Dollars.to_cents(@params[:price_in_dollars]).to_i if @params[:price_in_dollars]
    end

    def check
      errors.add(:base, "The price must be a dollar amount above zero") unless record.price_in_cents.to_i.positive?
    end

    def attach_photo
      record.photo.attach(@params[:photo])
      @photo_error = record.errors.full_messages_for(:photo).to_sentence.presence
    rescue StandardError => e
      Rails.logger.error("Catalog photo upload failed: #{e.class}: #{e.message}")
      discard_photo
      @photo_error = "The photo could not be stored. File storage may not be set up yet"
    end

    # delete, not purge: there is no stored file to remove.
    def discard_photo
      attachment = ActiveStorage::Attachment.find_by(record: record, name: "photo")
      blob = attachment&.blob
      attachment&.delete
      blob&.delete
    end
  end
end
