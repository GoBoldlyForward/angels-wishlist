# frozen_string_literal: true

module Admin
  class LoveBoxesController < BaseController
    def show
      @packing_list = PackingList.new(current_event)

      respond_to do |format|
        format.html
        format.csv do
          if params[:sheet] == "totals"
            send_data @packing_list.totals_csv, filename: "love-box-totals-#{Date.current}.csv", type: "text/csv"
          else
            send_csv(@packing_list, @packing_list.csv_columns, "love-boxes")
          end
        end
      end
    end
  end
end
