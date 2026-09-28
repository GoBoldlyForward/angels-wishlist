# frozen_string_literal: true

module Admin
  class VersionsController < BaseController
    def index
      @table = VersionsTable.new(params)

      respond_to do |format|
        format.html do
          @pagy, @versions = pagy(:offset, @table.rows)
          @subjects = AuditSubjects.new(@versions)
        end
        format.csv { send_csv(@table, @table.csv_columns, "audit-trail") }
      end
    end
  end
end
