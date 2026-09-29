# frozen_string_literal: true

class CurrentOrganizationsController < ApplicationController
  before_action :authenticate_user!

  def update
    organization = current_user.available_organizations.find_by(id: params[:organization_id])

    if organization
      session[:organization_id] = organization.id
      redirect_back_or_to admin_root_path, notice: "Now working in #{organization.display_name}."
    else
      redirect_back_or_to root_path, alert: "That organization is not one you can work in."
    end
  end
end
