# frozen_string_literal: true

module Admin
  class OrganizationsController < BaseController
    before_action :set_organization, only: %i[show edit update]

    def index
      @organizations = Organization.includes(:parent).order(:name).group_by(&:kind)
    end

    def show
    end

    def new
      @form = OrganizationForm.new(Organization.new(kind: new_kind, parent: current_chapter))
    end

    def create
      @form = OrganizationForm.new(Organization.new, organization_params)

      if @form.save
        redirect_to admin_organization_path(@form.record), notice: "#{@form.name} is added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @form = OrganizationForm.new(@organization)
    end

    def update
      @form = OrganizationForm.new(@organization, organization_params)

      if @form.save
        redirect_to admin_organization_path(@organization), notice: "Saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_organization
      @organization = Organization.friendly.find(params[:id])
    end

    def new_kind
      return "chapter" unless current_chapter

      Organization.kinds.key?(params[:kind]) ? params[:kind] : "agency"
    end

    def organization_params
      params.expect(organization: %i[name short_name kind parent_id website_url active co_brand_line theme_stylesheet])
    end
  end
end
