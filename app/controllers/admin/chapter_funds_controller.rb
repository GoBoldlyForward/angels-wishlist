# frozen_string_literal: true

module Admin
  class ChapterFundsController < BaseController
    def show
      @funds = ChapterFunds.new(current_chapter)
    rescue Stripe::StripeError => e
      @funds = nil
      flash.now[:alert] = "Stripe could not be reached. #{e.message}"
    end

    def release
      funds = ChapterFunds.new(current_chapter)
      cents = begin
        Dollars.to_cents(params[:amount_in_dollars]).to_i
      rescue ArgumentError
        0
      end
      refusal = funds.release(cents)

      if refusal
        redirect_to admin_chapter_funds_path, alert: refusal
      else
        redirect_to admin_chapter_funds_path, notice: "#{helpers.money_exact(cents)} is on its way to the chapter's bank."
      end
    rescue Stripe::StripeError => e
      redirect_to admin_chapter_funds_path, alert: "Stripe did not send it. #{e.message}"
    end
  end
end
