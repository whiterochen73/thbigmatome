module Api
  module V1
    class PlayerTypesController < Api::V1::BaseController
      # GET /api/v1/player-types
      def index
        @player_types = PlayerType.all.order(:id)
        render json: @player_types.to_json
      end

      # POST /api/v1/player-types
      def create
        render json: { error: I18n.t("master_data.managed_by_config_file") }, status: :forbidden
      end

      # PATCH/PUT /api/v1/player-types/:id
      def update
        render json: { error: I18n.t("master_data.managed_by_config_file") }, status: :forbidden
      end

      # DELETE /api/v1/player-types/:id
      def destroy
        render json: { error: I18n.t("master_data.managed_by_config_file") }, status: :forbidden
      end
    end
  end
end
