# frozen_string_literal: true

module Caregiver
  # What every intake step shares: the caregiver has started, the event still
  # takes changes, and the step is one they have reached.
  class IntakeController < BaseController
    class_attribute :step, instance_writer: false

    before_action :require_enrollment
    before_action :require_open_lists
    before_action :require_reached_step
    before_action :require_offered_step

    helper_method :step

    private

    def require_enrollment
      redirect_to caregiver_intake_home_path if current_enrollment.nil?
    end

    def require_open_lists
      if current_event.nil?
        redirect_to caregiver_root_path, alert: "Lists are not open yet. Check back soon."
      elsif current_event.closed?
        redirect_to caregiver_root_path, alert: "Lists are closed for #{current_event.name}, so nothing can be changed."
      end
    end

    def require_reached_step
      return if step.nil? || current_enrollment.reached?(step)

      redirect_to intake_step_path(current_enrollment.intake_step), alert: "Finish this step first."
    end

    # A step the chapter has switched off passes the caregiver on to the next one it asks for.
    def require_offered_step
      return if step.nil? || current_enrollment.nil? || current_enrollment.intake_steps.include?(step)

      following = current_enrollment.step_from(step)
      current_enrollment.advance_to!(following)
      redirect_to current_enrollment.submitted? ? caregiver_root_path : intake_step_path(following)
    end

    # Before submitting, a saved step leads to the next one. Afterwards the
    # caregiver is editing from the dashboard and goes back to it.
    def continue_to(next_step)
      next_step = current_enrollment.step_from(next_step)
      current_enrollment.advance_to!(next_step)
      return redirect_to caregiver_root_path, notice: "Saved.", status: :see_other if current_enrollment.submitted?

      redirect_to intake_step_path(next_step), status: :see_other
    end
  end
end
