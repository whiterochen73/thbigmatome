module Api
  module V1
    class BattingSkillsController < ApplicationController
      before_action :authenticate_user!

      # GET /api/v1/batting-skills
      def index
        @batting_skills = BattingSkill.all.order(:id)
        render json: @batting_skills.to_json
      end

      # POST /api/v1/batting-skills
      def create
        render json: { error: I18n.t("master_data.managed_by_config_file") }, status: :forbidden
      end

      # PATCH/PUT /api/v1/batting-skills/:id
      def update
        render json: { error: I18n.t("master_data.managed_by_config_file") }, status: :forbidden
      end

      # DELETE /api/v1/batting-skills/:id
      def destroy
        render json: { error: I18n.t("master_data.managed_by_config_file") }, status: :forbidden
      end
    end
  end
end
