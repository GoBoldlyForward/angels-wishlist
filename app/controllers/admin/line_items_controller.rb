# frozen_string_literal: true

module Admin
  class LineItemsController < BaseController
    before_action :set_line_item, only: %i[show edit update approve withdraw]
    before_action :refuse_if_funded, only: %i[edit update withdraw]

    def index
      @table = LineItemsTable.new(current_chapter, current_event, params)

      respond_to do |format|
        format.html { @pagy, @line_items = pagy(:offset, @table.rows_with_photos) }
        format.csv { send_csv(@table, @table.csv_columns, "line-items") }
      end
    end

    def show
      @wishlist = Figures.lists(Wishlist.where(id: @line_item.wishlist_id)).first
    end

    def edit
      @form = LineItemForm.new(@line_item)
    end

    def update
      @form = LineItemForm.new(@line_item, line_item_params)

      if @form.save
        redirect_to admin_line_item_path(@line_item), notice: "#{@line_item.name} is saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def approve
      @line_item.approve!
      redirect_back_or_to admin_line_item_path(@line_item),
                          notice: "#{@line_item.name} is approved at #{helpers.money(@line_item.price_in_cents)}."
    rescue ActiveRecord::RecordInvalid => invalid
      redirect_to admin_line_item_path(@line_item), alert: invalid.record.errors.full_messages.to_sentence
    end

    def withdraw
      @line_item.withdraw!
      redirect_to admin_line_item_path(@line_item), notice: "#{@line_item.name} is withdrawn."
    end

    private

    def set_line_item
      @line_item = LineItem.where(wishlist_id: Wishlist.where(event: current_event).select(:id))
                           .includes(wishlist: { child: :household }).find(params[:id])
    end

    def refuse_if_funded
      return unless @line_item.funded?

      redirect_to admin_line_item_path(@line_item),
                  alert: "A donor has chosen this gift, so it cannot be changed or withdrawn."
    end

    def line_item_params
      params.expect(line_item: LineItemForm::FIELDS)
    end
  end
end
