# frozen_string_literal: true

module Household
  class BaseController < ApplicationController
    layout "household"

    before_action :authenticate_user!
    before_action :require_caregiver

    private

    def require_caregiver
      redirect_to root_path, alert: "That area is for caregivers." unless current_user.caregiver?
    end
  end
end
