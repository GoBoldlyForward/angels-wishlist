# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    def index
      @overview = Overview.new(current_chapter, current_event) if current_event
    end
  end
end
