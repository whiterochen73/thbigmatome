module Api
  module V1
    class TeamsController < Api::V1::BaseController
      before_action :set_team, only: [ :show, :update, :destroy ]
      before_action :authorize_commissioner!, only: [ :create, :destroy ]

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
          begin
            update_managers(@team, team_params[:director_id], team_params[:coach_ids])
          rescue ActiveRecord::RecordInvalid => e
            render json: { error: e.message }, status: :unprocessable_entity
            return
          end
          render json: @team, status: :created, serializer: TeamSerializer
        else
          render json: { errors: @team.errors.full_messages }, status: :unprocessable_content
        end
      end

      # PATCH/PUT /api/v1/teams/:id
      def update
        if params.dig(:team, :team_type).present? && params.dig(:team, :team_type) != @team.team_type
          render json: { error: "team_type cannot be changed after creation" }, status: :unprocessable_entity
          return
        end

        if @team.update(team_params.except(:director_id, :coach_ids))
          begin
            update_managers(@team, team_params[:director_id], team_params[:coach_ids])
          rescue ActiveRecord::RecordInvalid => e
            render json: { error: e.message }, status: :unprocessable_entity
            return
          end
          render json: @team, serializer: TeamSerializer
        else
          render json: { errors: @team.errors.full_messages }, status: :unprocessable_content
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
        params.require(:team).permit(:name, :short_name, :is_active, :team_type, :director_id, coach_ids: [])
      end

      def update_managers(team, director_id, coach_ids)
        team.transaction do
          old_director_id = team.director_team_manager&.manager_id

          if director_id.present? && director_id.to_i != old_director_id
            new_director_team_ids = TeamManager.where(manager_id: director_id, role: :director)
                                               .pluck(:team_id)
            if new_director_team_ids.any?
              overlapping = TeamMembership.where(
                team_id: new_director_team_ids,
                player_id: team.team_memberships.pluck(:player_id)
              )
              if overlapping.exists?
                raise ActiveRecord::RecordInvalid,
                  "Director変更不可: 新しい監督の他チームと選手が重複しています"
              end
            end
          end

          team.director = director_id.present? ? Manager.find_by(id: director_id) : nil

          team.coach_team_managers.destroy_all
          if coach_ids.present?
            coach_ids.uniq.each do |id|
              team.coach_team_managers.create!(manager_id: id)
            end
          end
        end
      rescue ActiveRecord::RecordInvalid => e
        raise e
      end
    end
  end
end
