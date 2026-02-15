module Api
  module V1
    class TeamsController < Api::V1::BaseController
      before_action :set_team, only: [ :show, :update, :destroy ]

      # GET /api/v1/teams
      def index
        @teams = Team.preload(:director, :coaches).all
        render json: @teams, each_serializer: TeamSerializer
      end

      # GET /api/v1/teams/:id
      def show
        render json: @team, serializer: TeamSerializer
      end

      # POST /api/v1/teams
      def create
        @team = Team.new(team_params.except(:director_id, :coach_ids))

        if @team.save
          update_managers(@team, team_params[:director_id], team_params[:coach_ids])
          render json: @team, status: :created, serializer: TeamSerializer
        else
          render json: { errors: @team.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/teams/:id
      def update
        if @team.update(team_params.except(:director_id, :coach_ids))
          update_managers(@team, team_params[:director_id], team_params[:coach_ids])
          render json: @team, serializer: TeamSerializer
        else
          render json: { errors: @team.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/teams/:id
      def destroy
        @team.destroy
        head :no_content
      end

      private

      def set_team
        @team = Team.includes(:director, :coaches).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Team not found" }, status: :not_found
      end

      def team_params
        params.require(:team).permit(:name, :short_name, :is_active, :director_id, coach_ids: [])
      end

      def update_managers(team, director_id, coach_ids)
        team.transaction do
          team.director = director_id.present? ? Manager.find_by(id: director_id) : nil

          team.coach_team_managers.destroy_all
          if coach_ids.present?
            coach_ids.uniq.each do |id|
              team.coach_team_managers.create!(manager_id: id)
            end
          end
        end
      rescue ActiveRecord::RecordInvalid => e
        team.errors.add(:base, e.message)
        raise ActiveRecord::Rollback
      end
    end
  end
end
