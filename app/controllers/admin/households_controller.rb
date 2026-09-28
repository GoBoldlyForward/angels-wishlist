# frozen_string_literal: true

module Admin
  class HouseholdsController < BaseController
    before_action :set_household, only: %i[show edit update verify hold archive]

    def index
      @table = HouseholdsTable.new(current_chapter, current_event, params)

      respond_to do |format|
        format.html { @pagy, @households = pagy(:offset, @table.rows) }
        format.csv { send_csv(@table, @table.csv_columns, "households") }
      end
    end

    def show
      @profile = HouseholdProfile.new(@household, current_event)
    end

    def new
      @form = HouseholdForm.new(Household.new(organization: current_chapter))
    end

    def create
      @form = HouseholdForm.new(Household.new(organization: current_chapter), household_params)

      if @form.save(event: current_event)
        redirect_to admin_household_path(@form.household),
                    notice: "#{@form.household.display_name} is added. #{@form.caregiver.email} was sent a link to choose a password."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @form = HouseholdForm.new(@household)
    end

    def update
      @form = HouseholdForm.new(@household, household_params)

      if @form.save
        redirect_to admin_household_path(@household), notice: "#{@household.display_name} is saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def verify
      @household.verify!
      redirect_back_or_to admin_household_path(@household), notice: "#{@household.display_name} is verified."
    end

    def hold
      @household.hold!(params[:reason].to_s.strip)
      redirect_to admin_household_path(@household), notice: "#{@household.display_name} is on hold and will not be paid."
    rescue ActiveRecord::RecordInvalid
      redirect_to admin_household_path(@household), alert: "Give a reason to place a household on hold."
    end

    def archive
      @household.archive!
      redirect_to admin_households_path, notice: "#{@household.display_name} is archived."
    end

    private

    def set_household
      @household = Household.where(organization: current_chapter).friendly.find(params[:id])
    end

    def household_params
      params.expect(household: HouseholdForm::FIELDS)
    end
  end
end
