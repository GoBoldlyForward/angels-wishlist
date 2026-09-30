# frozen_string_literal: true

module Admin
  class OrganizationsController < BaseController
    FIELDS = %i[name short_name kind website_url active co_brand_line theme_stylesheet legal_name ein mail_from
                collects_payout_details].freeze
    ADMIN_FIELDS = %i[hostname platform_fee_basis_points].freeze

    skip_before_action :require_chapter, only: %i[index new create]
    before_action :set_organization, only: %i[show edit update]

    def index
      @organizations = reachable.includes(:parent).order(:name).group_by(&:kind)
    end

    def show
    end

    def new
      kind = allowed_kind(params[:kind])
      @form = OrganizationForm.new(Organization.new(kind: kind, parent: (current_chapter unless kind == "chapter")))
    end

    def create
      attributes = organization_params
      attributes[:kind] = allowed_kind(attributes[:kind])
      attributes[:parent_id] = (current_chapter&.id unless attributes[:kind] == "chapter")
      @form = OrganizationForm.new(Organization.new, attributes)

      if @form.save
        start_catalog(@form.record)
        redirect_to admin_organization_path(@form.record), notice: "#{@form.name} is added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @form = OrganizationForm.new(@organization)
    end

    def update
      @form = OrganizationForm.new(@organization, organization_params.except(:kind))

      if @form.save
        redirect_to admin_organization_path(@organization), notice: "Saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    # The chapter being worked in and what sits under it. An admin also sees every other chapter.
    def reachable
      scope = Organization.where(id: current_chapter).or(Organization.where(parent: current_chapter))
      current_user.admin? ? scope.or(Organization.chapter) : scope
    end

    def set_organization
      @organization = reachable.friendly.find(params[:id])
    end

    def allowed_kind(requested)
      return "chapter" if current_chapter.nil?

      kinds = current_user.admin? ? Organization.kinds.keys : %w[agency partner]
      kinds.include?(requested) ? requested : "agency"
    end

    def start_catalog(organization)
      source = Organization.chapter.where.not(id: organization.id).order(:id).first
      organization.copy_catalog_from(source) if organization.chapter? && source
    end

    def organization_params
      params.expect(organization: current_user.admin? ? FIELDS + ADMIN_FIELDS : FIELDS)
    end
  end
end
