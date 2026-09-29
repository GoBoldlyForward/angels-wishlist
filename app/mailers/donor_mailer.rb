# frozen_string_literal: true

class DonorMailer < ApplicationMailer
  def receipt(donation)
    @donation = donation
    @chapter = donation.event.organization
    donation.update_column(:receipt_sent_at, Time.current)
    mail to: donation.donor.email, from: from_chapter(@chapter), subject: "Your receipt from #{@chapter.name}"
  end

  def impact_statement(donor, event, message)
    @donor = donor
    @event = event
    @message = message
    @chapter = event.organization
    mail to: donor.email, from: from_chapter(@chapter), subject: "What your gift did this holiday"
  end
end
