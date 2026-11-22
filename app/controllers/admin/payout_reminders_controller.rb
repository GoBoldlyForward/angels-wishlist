# frozen_string_literal: true

module Admin
  class PayoutRemindersController < BaseController
    def create
      reminder = PayoutReminder.new(current_event)

      if reminder.deliver
        redirect_back_or_to admin_households_path,
                            notice: "The reminder is on its way to #{helpers.pluralize(reminder.recipient_count, 'household')}."
      else
        redirect_back_or_to admin_households_path, alert: reminder.refusal
      end
    end
  end
end
