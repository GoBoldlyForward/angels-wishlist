# frozen_string_literal: true

module Caregiver
  class BaseController < ApplicationController
    layout "caregiver"

    before_action :authenticate_user!
    before_action :require_caregiver

    private

    def require_caregiver
      redirect_to root_path, alert: "That area is for caregivers." unless current_user.caregiver?
    end
  end
end
