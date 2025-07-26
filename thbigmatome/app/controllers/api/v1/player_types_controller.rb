module Api
  module V1
    class PlayerTypesController < ApplicationController
      before_action :set_player_type, only: [:update, :destroy]

      # GET /api/v1/player-types
      def index
        @player_types = PlayerType.all.order(:id)
        render json: @player_types
      end

      # POST /api/v1/player-types
      def create
        @player_type = PlayerType.new(player_type_params)
        if @player_type.save
          render json: @player_type, status: :created
        else
          render json: { errors: @player_type.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/player-types/:id
      def update
        if @player_type.update(player_type_params)
          render json: @player_type
        else
          render json: { errors: @player_type.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/player-types/:id
      def destroy
        @player_type.destroy
        head :no_content
      end

      private

      def set_player_type
        @player_type = PlayerType.find(params[:id])
      end

      def player_type_params
        params.require(:player_type).permit(:name, :description)
      end
    end
  end
end