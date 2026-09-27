# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    layout "admin"

    helper Admin::TableHelper

    before_action :authenticate_user!
    before_action :require_admin

    private

    def require_admin
      redirect_to root_path, alert: "That area is for staff." unless current_user.is_admin?
    end

    def send_csv(table, columns, filename)
      send_data table.to_csv(columns), filename: "#{filename}-#{Date.current}.csv", type: "text/csv"
    end
  end
end
