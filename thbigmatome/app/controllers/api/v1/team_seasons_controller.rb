module Api
  module V1
    class TeamSeasonsController < Api::V1::BaseController
      include TeamAccessible
      before_action :authorize_team_access!

      def show
        team = Team.find(params[:team_id])
        season = team.season
        if season
          render json: season, serializer: SeasonDetailSerializer
        else
          render json: { error: "Season not found for this team" }, status: :not_found
        end
      end

      def update_season_schedule
        season_schedule = SeasonSchedule.find(params[:id])
        if season_schedule.update(season_schedule_params)
          render json: season_schedule
        else
          render json: season_schedule.errors, status: :unprocessable_content
        end
      end

      private


      def season_schedule_params
        params.require(:season_schedule).permit(:date_type)
      end
    end
  end
end
