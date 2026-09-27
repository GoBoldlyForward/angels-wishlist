# frozen_string_literal: true

module Caregiver
  # Sends one list back in after staff returned it or a child was added late.
  class ListSubmissionsController < ListsController
    def create
      wishlist = find_list(params[:list_id])
      unless Intake::ListState.new(wishlist, current_enrollment).ready_to_send?
        return redirect_to caregiver_intake_list_path(wishlist), status: :see_other,
                           alert: "Add at least one gift before sending this list in."
      end

      wishlist.submit!
      redirect_to caregiver_root_path, status: :see_other,
                  notice: "#{wishlist.child.legal_first_name}'s list is with staff for review."
    end
  end
end
