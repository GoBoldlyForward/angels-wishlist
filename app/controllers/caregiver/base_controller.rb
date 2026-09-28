# frozen_string_literal: true

module Caregiver
  class BaseController < ApplicationController
    layout "caregiver"

    before_action :authenticate_user!
    before_action :require_caregiver

    helper_method :current_household, :current_enrollment, :enrolled_lists, :intake_step_path

    private

    def require_caregiver
      redirect_to root_path, alert: "That area is for caregivers." unless current_user.caregiver?
    end

    def current_household
      return nil unless user_signed_in?

      @current_household ||= Intake::HomeForm.household_of(current_user, current_chapter)
    end

    def current_enrollment
      return nil if current_household.nil? || current_event.nil?

      @current_enrollment ||= current_household.enrollment_for(current_event)
    end

    def enrolled_lists
      current_enrollment.wishlists.merge(Child.active).includes(:child, line_items: :catalog_item)
                        .order("children.id")
    end

    def intake_step_path(step)
      public_send("caregiver_intake_#{step}_path")
    end
  end
end
