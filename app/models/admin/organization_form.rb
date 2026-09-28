# frozen_string_literal: true

module Admin
  class OrganizationForm < RecordForm
    PASSED_THROUGH = %w[name short_name kind parent_id website_url active co_brand_line].freeze

    delegate :name, :short_name, :kind, :parent_id, :website_url, :active, :co_brand_line, to: :record

    def theme_stylesheet
      record.theme["stylesheet"]
    end

    private

    def assign
      super
      return unless @params.key?(:theme_stylesheet)

      chosen = @params[:theme_stylesheet].presence
      record.theme = record.partner? && chosen ? record.theme.merge("stylesheet" => chosen) : record.theme.except("stylesheet")
    end

    def check
      return if theme_stylesheet.nil? || ApplicationHelper::THEME_STYLESHEETS.include?(theme_stylesheet)

      errors.add(:base, "Choose one of the bundled themes")
    end
  end
end
