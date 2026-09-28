# frozen_string_literal: true

module Public
  class BaseController < ApplicationController
    layout -> { turbo_frame_request? ? "turbo_rails/frame" : "public" }

    before_action :announce_dropped_gifts, if: -> { request.get? }

    helper_method :cart, :content, :open_cart?

    private

    # Keeps a partner's visitor inside the partner's storefront on every link. The key is
    # always present so a record passed to a route helper is never read as the storefront.
    def default_url_options
      { storefront: (current_storefront.slug if current_storefront&.partner?) }
    end

    def cart
      @cart ||= Storefront::Cart.new(session, event: current_event)
    end

    def catalog
      @catalog ||= Storefront::Catalog.new(event: current_event, cart_ids: cart.lines.map(&:id))
    end

    def content
      @content ||= Storefront::Content.new(chapter: current_chapter, event: current_event)
    end

    def filters
      @filters ||= Storefront::Filters.new(params.permit(:gender, :age, :price))
    end

    def announce_dropped_gifts
      cart.lines
      return if cart.dropped_count.zero?

      # A dialog has nowhere to show a notice, so it waits for the next full page.
      (turbo_frame_request? ? flash : flash.now)[:notice] = if cart.dropped_count == 1
        "A gift in your cart is no longer open, so we took it out."
      else
        "#{cart.dropped_count} gifts in your cart are no longer open, so we took them out."
      end
    end

    def added_to_cart(count, fallback:)
      if count.positive?
        session[:open_cart] = true
        flash[:notice] = "#{helpers.pluralize(count, 'gift')} added to your cart."
      else
        flash[:alert] = "That gift is no longer open. Someone may have chosen it first."
      end
      redirect_back_or_to fallback, status: :see_other
    end

    # True once, on the page shown right after the cart changed.
    def open_cart?
      session.delete(:open_cart).present?
    end
  end
end
