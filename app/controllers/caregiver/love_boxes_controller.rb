# frozen_string_literal: true

module Caregiver
  class LoveBoxesController < IntakeController
    self.step = "love_box"

    before_action :set_box

    def show
    end

    def update
      @box.assign(love_box_params)
      current_enrollment.save!
      return continue_to(:payout) if @box.complete?

      @missing = @box.missing_groups
      render :show, status: :unprocessable_entity
    end

    private

    def set_box
      @box = current_enrollment.love_box_selection
    end

    def love_box_params
      permitted = @box.groups.to_h { |group| [ group.id, [ :count, { picks: [] } ] ] }
      params.fetch(:love_box, {}).permit(permitted)
    end
  end
end
