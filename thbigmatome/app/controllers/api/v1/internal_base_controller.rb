class Api::V1::InternalBaseController < ApplicationController
  skip_before_action :set_csrf_token_header
  before_action :authenticate_internal_key!

  private

  def authenticate_internal_key!
    key = request.headers["X-Internal-Api-Key"] || params[:internal_api_key]
    expected = ENV["INTERNAL_API_KEY"]

    if expected.blank?
      render json: { error: "Internal API not configured" }, status: :service_unavailable
      return
    end

    unless ActiveSupport::SecurityUtils.secure_compare(key.to_s, expected)
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end
