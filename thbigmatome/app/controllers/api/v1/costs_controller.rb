class Api::V1::CostsController < ApplicationController
  def index
    costs = Cost.all
    render json: costs, each_serializer: CostSerializer
  end
end
