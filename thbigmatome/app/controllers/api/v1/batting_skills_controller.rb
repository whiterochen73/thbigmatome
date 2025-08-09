module Api
  module V1
    class BattingSkillsController < ApplicationController
      before_action :set_batting_skill, only: [:update, :destroy]

      # GET /api/v1/batting-skills
      def index
        @batting_skills = BattingSkill.all.order(:id)
        render json: @batting_skills.to_json
      end

      # POST /api/v1/batting-skills
      def create
        @batting_skill = BattingSkill.new(batting_skill_params)
        if @batting_skill.save
          render json: @batting_skill, status: :created
        else
          render json: { errors: @batting_skill.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/batting-skills/:id
      def update
        if @batting_skill.update(batting_skill_params)
          render json: @batting_skill
        else
          render json: { errors: @batting_skill.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/batting-skills/:id
      def destroy
        @batting_skill.destroy
        head :no_content
      end

      private

      def set_batting_skill
        @batting_skill = BattingSkill.find(params[:id])
      end

      def batting_skill_params
        params.require(:batting_skill).permit(:name, :description, :skill_type)
      end
    end
  end
end
