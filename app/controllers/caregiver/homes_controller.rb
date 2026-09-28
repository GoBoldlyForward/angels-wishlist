# frozen_string_literal: true

module Caregiver
  class HomesController < IntakeController
    self.step = "home"

    skip_before_action :authenticate_user!, only: %i[show create]
    skip_before_action :require_enrollment, :require_reached_step

    invisible_captcha only: :create, honeypot: :nickname, timestamp_enabled: false, on_spam: :start_over
    rate_limit to: 10, within: 10.minutes, only: :create,
               with: -> { redirect_to caregiver_intake_home_path, alert: "Too many tries. Wait a few minutes and try again." }

    def show
      @form = build_form
    end

    def create
      @form = build_form(home_params)
      return render :show, status: :unprocessable_entity unless @form.save

      sign_in(@form.user) unless user_signed_in?
      continue_to(:children)
    end

    def update
      @form = build_form(home_params.except(:password))
      return render :show, status: :unprocessable_entity unless @form.save

      continue_to(:children)
    end

    private

    def require_caregiver
      super if user_signed_in?
    end

    def start_over
      redirect_to caregiver_intake_home_path, alert: "That did not go through. Please try once more."
    end

    def build_form(attributes = nil)
      Intake::HomeForm.new(user: current_user, organization: current_chapter, event: current_event,
                           attributes: attributes)
    end

    def home_params
      params.expect(home: %i[first_name last_name email password phone county street_line_1 city zipcode])
    end
  end
end
