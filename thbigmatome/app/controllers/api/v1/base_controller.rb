class Api::V1::BaseController < ApplicationController
  respond_to :json

  private

  def render_json_response(object, status = :ok)
    render json: object, status: status
  end
end
