# frozen_string_literal: true

class StripeWebhooksController < ActionController::API
  def create
    event = PaymentGateway.construct_event(request.body.read, request.headers["Stripe-Signature"])
    PaymentGateway.handle(event)
    head :ok
  rescue JSON::ParserError, Stripe::SignatureVerificationError
    head :bad_request
  end
end
