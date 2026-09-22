# frozen_string_literal: true

# No browser client outside this origin needs the API, so the allowed origins
# list stays empty until one actually exists.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("CORS_ORIGINS", "").split(",").map(&:strip).reject(&:empty?)
    resource "/api/*", headers: :any, methods: [ :get, :post, :options ]
  end
end
