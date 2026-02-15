module Api
  module V1
    class PitchingStylesController < ApplicationController
      before_action :authenticate_user!

      # GET /api/v1/pitching-styles
      def index
        @pitching_styles = PitchingStyle.all.order(:id)
        render json: @pitching_styles.to_json
      end

      # POST /api/v1/pitching-styles
      def create
        render json: { error: I18n.t("master_data.managed_by_config_file") }, status: :forbidden
      end

      # PATCH/PUT /api/v1/pitching-styles/:id
      def update
        render json: { error: I18n.t("master_data.managed_by_config_file") }, status: :forbidden
      end

      # DELETE /api/v1/pitching-styles/:id
      def destroy
        render json: { error: I18n.t("master_data.managed_by_config_file") }, status: :forbidden
      end
    end
  end
end
