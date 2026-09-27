# frozen_string_literal: true

module Admin
  class DonorsController < FundingController
    def index
      @table = DonorsTable.new(current_event, params)

      respond_to do |format|
        format.html { @pagy, @rows = pagy(:offset, @table.rows) }
        format.csv { send_csv(@table, DonorsTable::CSV_COLUMNS, "donors") }
      end
    end

    def show
      user = User.where(id: current_event.donations.select(:donor_id)).friendly.find(params[:id])
      @donor = Donor.new(user, current_event)
    end
  end
end
