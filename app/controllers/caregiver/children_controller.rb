# frozen_string_literal: true

module Caregiver
  class ChildrenController < IntakeController
    self.step = "children"

    def show
      @form = build_form
    end

    def update
      @form = build_form(children_params)
      return add_child if params[:add_child].present?
      return render :show, status: :unprocessable_entity unless @form.save

      continue_to(:lists)
    end

    private

    # Adding a child saves nothing, so a half-filled page is not refused.
    def add_child
      @entry = @form.add_blank

      respond_to do |format|
        format.turbo_stream
        format.html { render :show, status: :unprocessable_entity }
      end
    end

    def build_form(rows = nil)
      Intake::ChildrenForm.new(household: current_household, event: current_event, rows: rows)
    end

    def children_params
      rows = params[:children]
      return {} unless rows.is_a?(ActionController::Parameters)

      rows.each_pair.to_h do |key, row|
        [ key, row.is_a?(ActionController::Parameters) ? row.permit(*Intake::ChildrenForm::PERMITTED) : {} ]
      end
    end
  end
end
