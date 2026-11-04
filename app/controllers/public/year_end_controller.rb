# frozen_string_literal: true

module Public
  # The chapter's year-end giving page, with nothing to shop: pick a gift, then give.
  class YearEndController < BaseController
    def show
      @appeal = year_end_appeal
      redirect_to root_path unless @appeal.enabled?
    end

    private

    def hide_cart?
      true
    end
  end
end
