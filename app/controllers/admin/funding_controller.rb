# frozen_string_literal: true

module Admin
  # The funding pages all read one event's money, so they need an event to exist.
  class FundingController < BaseController
    before_action :require_event

    private

    def require_event
      redirect_to admin_events_path, alert: "Set up an event first." unless current_event
    end
  end
end
