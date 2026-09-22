# frozen_string_literal: true

class Rack::Attack
  ### Throttles

  # Anyone hammering the site from one address.
  throttle("req/ip", limit: 300, period: 5.minutes, &:ip)

  # Credential stuffing: by address, and by the account being targeted.
  throttle("logins/ip", limit: 10, period: 20.seconds) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  throttle("logins/email", limit: 6, period: 20.minutes) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.params.dig("user", "email").to_s.downcase.presence
    end
  end

  throttle("signups/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.path == "/users" && req.post?
  end

  # Password reset is an email-sending endpoint, so it is throttled harder.
  throttle("password_resets/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.path == "/users/password" && req.post?
  end

  # Checkout hits Stripe, so a loop here costs money.
  throttle("checkout/ip", limit: 10, period: 10.minutes) do |req|
    req.ip if req.path.start_with?("/checkout") && req.post?
  end

  self.throttled_responder = lambda do |_request|
    [ 429, { "Content-Type" => "text/plain" }, [ "Too many requests. Try again shortly.\n" ] ]
  end
end
