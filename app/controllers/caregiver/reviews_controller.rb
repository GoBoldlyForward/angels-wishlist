# frozen_string_literal: true

module Caregiver
  class ReviewsController < IntakeController
    self.step = "review"

    def show
      @lists = enrolled_lists
      @box = current_enrollment.love_box_selection
      @blockers = current_enrollment.blockers
    end
  end
end
