module Api
  module V1
    class TeamsController < Api::V1::BaseController
      include TeamAccessible
      include DirectorSiblingCheck

      before_action :set_team, only: [ :show, :update, :destroy ]
      before_action :authorize_commissioner!, only: [ :create, :destroy ]
      before_action :authorize_team_access!, only: [ :show, :update ]

      # GET /api/v1/teams
      def index
        @teams = Team.preload(:director, :coaches)
                     .select(
                       "teams.*",
                       "(SELECT MAX(g.real_date) FROM games g " \
                       " WHERE g.home_team_id = teams.id OR g.visitor_team_id = teams.id) AS last_game_real_date",
                       "(SELECT MAX(gr.game_date) FROM game_records gr " \
                       " WHERE gr.team_id = teams.id) AS last_game_date",
                       "(SELECT s.current_date FROM seasons s WHERE s.team_id = teams.id LIMIT 1) AS season_current_date"
                     )
                     .order(is_active: :desc, updated_at: :desc)
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
          rescue ActiveRecord::RecordInvalid, DirectorSiblingCheck::OverlapError => e
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
          rescue ActiveRecord::RecordInvalid, DirectorSiblingCheck::OverlapError => e
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
        if @team.destroy
          head :no_content
        else
          render json: { errors: @team.errors.full_messages }, status: :unprocessable_entity
        end
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
            check_director_sibling_overlap!(team, director_id)
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
