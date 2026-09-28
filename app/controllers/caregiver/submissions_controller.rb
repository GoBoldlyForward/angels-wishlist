# frozen_string_literal: true

module Caregiver
  class SubmissionsController < IntakeController
    self.step = "review"

    def show
      return redirect_to caregiver_intake_review_path unless current_enrollment.submitted?

      @lists_count = enrolled_lists.size
    end

    def create
      return redirect_to caregiver_root_path, status: :see_other if current_enrollment.submitted?

      unless current_enrollment.ready_to_submit?
        return redirect_to caregiver_intake_review_path, status: :see_other,
                           alert: "A few things are still missing before you can submit."
      end

      current_enrollment.submit!
      CaregiverMailer.lists_received(current_enrollment).deliver_later
      redirect_to caregiver_intake_submission_path, status: :see_other
    end
  end
end
