# frozen_string_literal: true

module Admin
  class InboxesController < BaseController
    def show
      @queues = ReviewQueues.new(Inbox.new(current_event))
    end
  end
end
