# frozen_string_literal: true

module Caregiver
  class PayoutsController < IntakeController
    self.step = "payout"

    def show
      @form = Intake::PayoutForm.new(enrollment: current_enrollment)
    end

    def update
      @form = Intake::PayoutForm.new(enrollment: current_enrollment, attributes: payout_params)
      return render :show, status: :unprocessable_entity unless @form.save

      continue_to(:review)
    end

    private

    def payout_params
      params.expect(payout: %i[payout_method agreed street_line_1 city zipcode])
    end
  end
end
