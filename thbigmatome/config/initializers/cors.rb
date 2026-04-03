# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

# Rails.application.config.middleware.insert_before 0, Rack::Cors do
#   allow do
#     origins "example.com"
#
#     resource "*",
#       headers: :any,
#       methods: [:get, :post, :put, :patch, :delete, :options, :head]
#   end
# end
# CORS_ALLOWED_ORIGIN 環境変数で許可するオリジンを指定する。
# 複数指定する場合はカンマ区切りで列挙（例: "https://example.com,https://www.example.com"）。
# 未設定時は開発用デフォルト（localhost:5173）にフォールバック。
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allowed_origins = ENV.fetch("CORS_ALLOWED_ORIGIN", "http://localhost:5173").split(",").map(&:strip)

  allow do
    origins(*allowed_origins)
    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: true,
      expose: [ "X-CSRF-Token" ]
  end
end
