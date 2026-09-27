# frozen_string_literal: true

class CaregiverMailer < ApplicationMailer
  def lists_received(enrollment)
    @enrollment = enrollment
    @household = enrollment.household
    mail to: @household.caregiver.email, subject: "We have your lists"
  end

  def lists_live(household, event)
    @household = household
    @event = event
    mail to: household.caregiver.email, subject: "Your lists are live"
  end

  def list_returned(wishlist)
    @wishlist = wishlist
    @household = wishlist.household
    mail to: @household.caregiver.email, subject: "One of your lists needs a change"
  end

  def payout_sent(payout)
    @payout = payout
    @household = payout.household
    mail to: @household.caregiver.email, subject: "Your holiday funds are on the way"
  end
end
