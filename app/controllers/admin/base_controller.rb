# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    layout "admin"

    before_action :authenticate_user!
    before_action :require_admin

    private

    def require_admin
      redirect_to root_path, alert: "That area is for staff." unless current_user.is_admin?
    end
  end
end
