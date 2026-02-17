module Api
  module V1
    class PitchingSkillsController < Api::V1::BaseController
      # GET /api/v1/pitching-skills
      def index
        @pitching_skills = PitchingSkill.all.order(:id)
        render json: @pitching_skills.to_json
      end

      # POST /api/v1/pitching-skills
      def create
        render json: { error: I18n.t("master_data.managed_by_config_file") }, status: :forbidden
      end

      # PATCH/PUT /api/v1/pitching-skills/:id
      def update
        render json: { error: I18n.t("master_data.managed_by_config_file") }, status: :forbidden
      end

      # DELETE /api/v1/pitching-skills/:id
      def destroy
        render json: { error: I18n.t("master_data.managed_by_config_file") }, status: :forbidden
      end
    end
  end
end
