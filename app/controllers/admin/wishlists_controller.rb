# frozen_string_literal: true

module Admin
  class WishlistsController < BaseController
    before_action :set_wishlist, only: %i[show approve return_to_caregiver withdraw]

    def index
      @table = WishlistsTable.new(current_chapter, current_event, params)

      respond_to do |format|
        format.html { @pagy, @wishlists = pagy(:offset, @table.rows) }
        format.csv { send_csv(@table, @table.csv_columns, "wishlists") }
      end
    end

    def show
      @line_items = @wishlist.line_items.includes({ donation: :donor }, catalog_item: { photo_attachment: :blob })
                             .oldest_first
    end

    def approve
      if @review.approve
        redirect_back_or_to admin_wishlist_path(@wishlist), notice: "#{@wishlist.child.display_name}'s list is live."
      else
        redirect_to admin_wishlist_path(@wishlist), alert: @review.error
      end
    end

    def return_to_caregiver
      if @review.return_to_caregiver(params[:reason])
        redirect_to admin_wishlist_path(@wishlist),
                    notice: "#{@wishlist.child.display_name}'s list went back to the caregiver with your note."
      else
        redirect_to admin_wishlist_path(@wishlist), alert: @review.error
      end
    end

    def withdraw
      if @review.withdraw
        redirect_to admin_wishlist_path(@wishlist), notice: "#{@wishlist.child.display_name}'s list is withdrawn."
      else
        redirect_to admin_wishlist_path(@wishlist), alert: @review.error
      end
    end

    private

    def set_wishlist
      @wishlist = Figures.lists(Wishlist.where(event: current_event)).includes(child: { household: :caregiver })
                         .friendly.find(params[:id])
      @review = WishlistReview.new(@wishlist)
    end
  end
end
