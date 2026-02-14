class Api::V1::CostsController < ApplicationController
  before_action :set_cost, only: [:update, :duplicate, :destroy]

  def index
    costs = Cost.all
    render json: costs, each_serializer: CostSerializer
  end

  def create
    cost = Cost.new(cost_params)
    if cost.save
      render json: cost, status: :created
    else
      render json: cost.errors, status: :unprocessable_entity
    end
  end

  def update
    if @cost.update(cost_params)
      render json: @cost
    else
      render json: @cost.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @cost.destroy
    head :no_content
  end

  def duplicate
    duplicated_cost = nil
    ActiveRecord::Base.transaction do
      # Costを複製
      duplicated_cost = @cost.dup
      duplicated_cost.name = "#{@cost.name} (コピー)"
      if @cost.start_date.present?
        duplicated_cost.start_date = @cost.start_date.next_year
      end
      if @cost.end_date.present?
        duplicated_cost.end_date = @cost.end_date.next_year
      end
      duplicated_cost.save!

      # CostPlayerも複製
      @cost.cost_players.each do |cost_player|
        new_cost_player = cost_player.dup
        new_cost_player.cost = duplicated_cost # 複製したCostに紐付け
        new_cost_player.save!
      end
    end
    render json: duplicated_cost, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def set_cost
    @cost = Cost.find(params[:id])
  end

  def cost_params
    params.require(:cost).permit(:name, :start_date, :end_date)
  end
end
