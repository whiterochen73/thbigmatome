class Api::V1::BaseController < ApplicationController
  respond_to :json
  before_action :authenticate_user!

  private

  def authorize_commissioner!
    unless current_user&.commissioner?
      render json: { errors: [ "Forbidden" ] }, status: :forbidden
    end
  end

  def render_json_response(object, status = :ok)
    render json: object, status: status
  end
end
