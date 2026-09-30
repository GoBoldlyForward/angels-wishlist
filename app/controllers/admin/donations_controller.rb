# frozen_string_literal: true

module Admin
  class DonationsController < FundingController
    before_action :set_donation, only: %i[show refund resend_receipt]

    def index
      @table = DonationsTable.new(current_event, params)

      respond_to do |format|
        format.html { @pagy, @rows = pagy(:offset, @table.rows) }
        format.csv { send_csv(@table, DonationsTable::CSV_COLUMNS, "donations") }
      end
    end

    def show
      @choice = DonationChoice.new(@donation)
    end

    def new
      @offline_gift = OfflineGift.new(event: current_event)
    end

    def create
      @offline_gift = OfflineGift.new(offline_gift_params.merge(event: current_event))

      if @offline_gift.save
        redirect_to admin_donation_path(@offline_gift.donation), notice: "The gift is recorded and part of the pool."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def refund
      return redirect_to(admin_donation_path(@donation), alert: "Only a succeeded donation can be refunded.") unless @donation.succeeded?

      PaymentGateway.refund(@donation)
      redirect_to admin_donation_path(@donation), notice: "Refunded. Its gifts are open again."
    rescue Stripe::StripeError => e
      redirect_to admin_donation_path(@donation), alert: "Stripe did not accept the refund. #{e.message}"
    end

    def resend_receipt
      return redirect_back_or_to(admin_donation_path(@donation), alert: "A receipt goes out once a donation succeeds.") unless @donation.succeeded?

      DonorMailer.receipt(@donation).deliver_later
      redirect_back_or_to admin_donation_path(@donation), notice: "The receipt is on its way to #{@donation.donor.email}."
    end

    private

    def set_donation
      @donation = Donation.where(event: current_chapter.events).includes(:donor, :event, line_items: { wishlist: :child })
                          .find_by!(uuid: params[:id])
    end

    def offline_gift_params
      params.expect(offline_gift: %i[donor_name email amount_in_dollars given_on payment_method_label display_name anonymous])
    end
  end
end
