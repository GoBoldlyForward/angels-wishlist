# frozen_string_literal: true

module Public
  class CheckoutsController < BaseController
    def show
      return redirect_to(cart_path) if cart.empty?

      @checkout = build_checkout
    end

    def create
      @checkout = build_checkout(checkout_params)

      if @checkout.save
        redirect_to pay_for(@checkout.donation).url, allow_other_host: true, status: :see_other
      else
        render :show, status: :unprocessable_content
      end
    end

    private

    def checkout_params
      params.expect(checkout: %i[email display_name note_to_family cover_fee])
    end

    def build_checkout(attributes = {})
      Storefront::Checkout.new(attributes, cart: cart, event: current_event, storefront: current_storefront,
                                           visit: current_visit)
    end

    # The gateway sends the receipt itself once a live payment settles.
    def pay_for(donation)
      checkout = PaymentGateway.start_checkout(donation, success_url: success_url_for(donation),
                                                         cancel_url: donation_url(donation))
      DonorMailer.receipt(donation).deliver_later unless PaymentGateway.live?
      checkout
    end

    # Stripe fills in the placeholder, so it has to reach Stripe unescaped.
    def success_url_for(donation)
      return donation_url(donation) unless PaymentGateway.live?

      "#{donation_url(donation)}?session_id={CHECKOUT_SESSION_ID}"
    end
  end
end
