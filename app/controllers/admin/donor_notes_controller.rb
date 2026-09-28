# frozen_string_literal: true

module Admin
  class DonorNotesController < BaseController
    before_action :set_donation

    def approve
      @donation.approve_note!
      redirect_back_or_to admin_inbox_path, notice: "The note from #{@donation.public_display_name} is approved."
    end

    def discard
      @donation.discard_note!
      redirect_back_or_to admin_inbox_path, notice: "The note from #{@donation.public_display_name} is discarded."
    end

    private

    def set_donation
      @donation = Donation.where(event: current_event).find_by!(uuid: params[:id])
    end
  end
end
