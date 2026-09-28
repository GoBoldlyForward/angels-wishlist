# frozen_string_literal: true

module Caregiver
  class GiftsController < ListsController
    before_action :set_wishlist

    def create
      @gift = Intake::GiftEntry.new(**gift_params.to_h.symbolize_keys)
      return redirect_to caregiver_intake_list_path(@wishlist), status: :see_other if @gift.add_to(@wishlist)

      render "caregiver/lists/show", status: :unprocessable_entity
    end

    def destroy
      line_item = @wishlist.line_items.find(params[:id])
      return redirect_to caregiver_intake_list_path(@wishlist), status: :see_other if line_item.destroy

      redirect_to caregiver_intake_list_path(@wishlist), status: :see_other,
                  alert: "A donor already chose #{line_item.name}, so it stays on the list."
    end

    private

    def set_wishlist
      @wishlist = find_list(params[:list_id])
    end

    def gift_params
      params.expect(gift: %i[name price link])
    end
  end
end
