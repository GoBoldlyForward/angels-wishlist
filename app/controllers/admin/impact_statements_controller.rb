# frozen_string_literal: true

module Admin
  class ImpactStatementsController < FundingController
    def new
      @impact_statement = ImpactStatement.new(event: current_event)
    end

    def create
      @impact_statement = ImpactStatement.new(impact_statement_params.merge(event: current_event))

      if @impact_statement.deliver
        redirect_to admin_donors_path,
                    notice: "The impact statement is on its way to #{helpers.pluralize(@impact_statement.recipient_count, 'donor')}."
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def impact_statement_params
      params.expect(impact_statement: [ :message ])
    end
  end
end
