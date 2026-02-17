module Api
  module V1
    class BattingStylesController < Api::V1::BaseController
      # GET /api/v1/batting-styles
      def index
        @batting_styles = BattingStyle.all.order(:id)
        render json: @batting_styles.to_json
      end

      # POST /api/v1/batting-styles
      def create
        render json: { error: I18n.t("master_data.managed_by_config_file") }, status: :forbidden
      end

      # PATCH/PUT /api/v1/batting-styles/:id
      def update
        render json: { error: I18n.t("master_data.managed_by_config_file") }, status: :forbidden
      end

      # DELETE /api/v1/batting-styles/:id
      def destroy
        render json: { error: I18n.t("master_data.managed_by_config_file") }, status: :forbidden
      end
    end
  end
end
