# frozen_string_literal: true

module Caregiver
  class DashboardController < BaseController
    skip_before_action :authenticate_user!

    def index
      return render :landing unless user_signed_in? && (current_enrollment&.submitted? || taking_lists?)
      return redirect_to caregiver_intake_home_path if current_enrollment.nil?
      return redirect_to intake_step_path(current_enrollment.intake_step) unless current_enrollment.submitted?

      @lists = enrolled_lists
      @box = current_enrollment.love_box_selection
    end

    private

    def require_caregiver
      super if user_signed_in?
    end

    def taking_lists?
      current_event.present? && !current_event.closed?
    end
  end
end
