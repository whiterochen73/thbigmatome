module Api
  module V1
    class TeamSeasonsController < ApplicationController
      def show
        team = Team.find(params[:team_id])
        season = team.season
        if season
          render json: season, serializer: SeasonDetailSerializer
        else
          render json: { error: 'Season not found for this team' }, status: :not_found
        end
      end

      def update
        team = Team.find(params[:team_id])
        season = team.season # Assuming a team has one season

        if season.update(season_params)
          render json: { season: season }, status: :ok
        else
          render json: { errors: season.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: e.message }, status: :not_found
      end

      def update_season_schedule
        season_schedule = SeasonSchedule.find(params[:id])
        if season_schedule.update(season_schedule_params)
          render json: season_schedule
        else
          render json: season_schedule.errors, status: :unprocessable_entity
        end
      end

      private


      def season_params
        params.require(:season).permit(:current_date)
      end

      def season_schedule_params
        params.require(:season_schedule).permit(:date_type)
      end
    end
  end
end
