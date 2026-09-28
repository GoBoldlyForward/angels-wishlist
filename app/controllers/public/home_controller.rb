# frozen_string_literal: true

module Public
  class HomeController < BaseController
    TABS = %w[browse children unfunded give].freeze

    def index
      @catalog = catalog
      @filters = filters
      @tab = TABS.include?(params[:tab]) ? params[:tab] : TABS.first
      @season = Storefront::Season.new(current_event, catalog) if current_event
    end
  end
end
