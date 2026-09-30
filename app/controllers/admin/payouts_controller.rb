# frozen_string_literal: true

module Admin
  class PayoutsController < FundingController
    before_action :set_payout, only: %i[show send_funds mark_delivered]

    def index
      @table = PayoutsTable.new(current_event, params)
      @run = @table.run

      respond_to do |format|
        format.html { @pagy, @households = pagy(:offset, @table.rows) }
        format.csv { send_csv(@table, @table.csv_columns, "payouts") }
      end
    end

    def show
      @row = PayoutRun.new(@payout.event).row_for(@payout.household)
    end

    def build
      payouts = current_event.build_payouts!
      redirect_to admin_payouts_path, notice: "Payouts are built for #{helpers.pluralize(payouts.size, 'household')}."
    end

    def send_funds
      dispatch = PayoutDispatch.new(@payout, tracking_number: params.dig(:payout, :gift_card_tracking_number))

      if dispatch.call
        redirect_to admin_payout_path(@payout), notice: "Sent. #{@payout.household.caregiver.email} has been told."
      else
        redirect_to admin_payout_path(@payout), alert: dispatch.error
      end
    end

    def mark_delivered
      return redirect_to(admin_payout_path(@payout), alert: "Only a sent payout can be marked delivered.") unless @payout.sent?

      @payout.mark_delivered!
      redirect_to admin_payout_path(@payout), notice: "Marked delivered."
    end

    private

    def set_payout
      @payout = Payout.where(event: current_chapter.events).includes(household: %i[caregiver mailing_address])
                      .find(params[:id])
    end
  end
end
