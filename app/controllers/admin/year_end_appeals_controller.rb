# frozen_string_literal: true

module Admin
  class YearEndAppealsController < BaseController
    def show
      @form = YearEndAppealForm.new(current_chapter)
    end

    def update
      @form = YearEndAppealForm.new(current_chapter, appeal_params)

      if @form.save
        redirect_to admin_year_end_appeal_path, notice: "Saved. The checkout page shows it now."
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def appeal_params
      params.expect(year_end_appeal: [ :enabled, :headline, :lede, :period, :source_label, :source_url,
                                       stats: {}, tiers: {} ])
    end
  end
end
