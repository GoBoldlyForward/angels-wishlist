# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    layout "admin"

    helper Admin::TableHelper

    before_action :authenticate_user!
    before_action :require_staff

    private

    def require_staff
      return if current_user.admin? || current_user.organizes?(current_chapter)

      redirect_to root_path, alert: "That area is for staff."
    end

    # A partner's organizer works inside the chapter the partner belongs to.
    def current_chapter
      return @current_chapter if defined?(@current_chapter)

      @current_chapter = current_organization&.partner? ? current_organization.parent : current_organization
    end

    def send_csv(table, columns, filename)
      send_data table.to_csv(columns), filename: "#{filename}-#{Date.current}.csv", type: "text/csv"
    end
  end
end
