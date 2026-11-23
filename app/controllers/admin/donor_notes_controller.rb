# frozen_string_literal: true

module Admin
  class DonorNotesController < BaseController
    before_action :set_donation
    before_action :refuse_unless_awaiting_approval, only: :update

    def update
      if @donation.revise_note(note_params[:note_to_family])
        redirect_back_or_to admin_inbox_path, notice: "The note from #{@donation.public_display_name} is saved."
      else
        redirect_back_or_to admin_inbox_path, alert: @donation.errors.full_messages.to_sentence
      end
    end

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

    def refuse_unless_awaiting_approval
      return if @donation.note_pending_review?

      redirect_back_or_to admin_inbox_path, alert: "Only a note waiting for approval can be edited."
    end

    def note_params
      params.expect(donor_note: [ :note_to_family ])
    end
  end
end
