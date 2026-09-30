# frozen_string_literal: true

module Caregiver
  class ListsController < IntakeController
    self.step = "lists"

    before_action :set_lists
    before_action :require_a_child

    def index
      redirect_to caregiver_intake_list_path(@lists.first)
    end

    def show
      @wishlist = find_list(params[:id])
      @gift = Intake::GiftEntry.new
    end

    def finish
      empty = @lists.find { |list| list.line_items.none? { |line| !line.withdrawn_status? } }
      return continue_to(:love_box) if empty.nil?

      redirect_to caregiver_intake_list_path(empty), status: :see_other,
                  alert: "Add at least one gift for #{empty.child.legal_first_name}."
    end

    private

    def set_lists
      @lists = enrolled_lists.where(status: %w[draft in_review live]).to_a
    end

    def require_a_child
      redirect_to caregiver_intake_children_path, alert: "Add a child first." if @lists.empty?
    end

    def find_list(id)
      @lists.find { |list| list.to_param == id.to_s } || raise(ActiveRecord::RecordNotFound)
    end
  end
end
