# frozen_string_literal: true

module Public
  class BaseController < ApplicationController
    layout "public"

    private

    # Keeps a partner's visitor inside the partner's storefront on every link.
    def default_url_options
      current_storefront&.partner? ? { storefront: current_storefront.slug } : {}
    end
  end
end
