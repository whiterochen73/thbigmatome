module Api
  module V1
    class CostsController < ApplicationController
      before_action :set_cost, only: [:show, :update, :destroy]

      # GET /api/v1/costs
      def index
        @costs = Cost.all
        render json: @costs
      end

      # GET /api/v1/costs/:id
      def show
        render json: @cost
      end

      # POST /api/v1/costs
      def create
        @cost = Cost.new(cost_params)
        if @cost.save
          render json: @cost, status: :created
        else
          render json: @cost.errors, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/costs/:id
      def update
        if @cost.update(cost_params)
          render json: @cost
        else
          render json: @cost.errors, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/costs/:id
      def destroy
        @cost.destroy
        head :no_content
      end

      private

      def set_cost
        @cost = Cost.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Cost not found' }, status: :not_found
      end

      def cost_params
        params.require(:cost).permit(:name, :start_date, :end_date)
      end
    end
  end
end