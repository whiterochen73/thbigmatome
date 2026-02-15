module Api
  module V1
    class PitchingSkillsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_pitching_skill, only: [ :update, :destroy ]

      # GET /api/v1/pitching-skills
      def index
        @pitching_skills = PitchingSkill.all.order(:id)
        render json: @pitching_skills.to_json
      end

      # POST /api/v1/pitching-skills
      def create
        @pitching_skill = PitchingSkill.new(pitching_skill_params)
        if @pitching_skill.save
          render json: @pitching_skill, status: :created
        else
          render json: { errors: @pitching_skill.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/pitching-skills/:id
      def update
        if @pitching_skill.update(pitching_skill_params)
          render json: @pitching_skill
        else
          render json: { errors: @pitching_skill.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/pitching-skills/:id
      def destroy
        @pitching_skill.destroy
        head :no_content
      end

      private

      def set_pitching_skill
        @pitching_skill = PitchingSkill.find(params[:id])
      end

      def pitching_skill_params
        params.require(:pitching_skill).permit(:name, :description, :skill_type)
      end
    end
  end
end
