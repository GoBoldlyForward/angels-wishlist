# frozen_string_literal: true

module Public
  class ChildrenController < BaseController
    def show
      @child = catalog.child(params[:id]) || raise(ActiveRecord::RecordNotFound)
    end
  end
end
