module Api
  module V1
    class GameLineupsController < Api::V1::BaseController
      include TeamAccessible

      before_action :set_team
      before_action :authorize_team_access!

      # GET /api/v1/teams/:team_id/game_lineup
      def show
        @game_lineup = @team.game_lineup
        if @game_lineup
          render json: serialize_game_lineup(@game_lineup)
        else
          render json: { error: "Not found" }, status: :not_found
        end
      end

      # PUT /api/v1/teams/:team_id/game_lineup
      def update
        lineup_data = params.dig(:game_lineup, :lineup_data)

        @game_lineup = @team.game_lineup || @team.build_game_lineup
        if @game_lineup.update(lineup_data: lineup_data)
          render json: serialize_game_lineup(@game_lineup)
        else
          render json: { errors: @game_lineup.errors.full_messages }, status: :unprocessable_content
        end
      end

      private

      def set_team
        @team = Team.find(params[:team_id])
      end

      def serialize_game_lineup(game_lineup)
        {
          id: game_lineup.id,
          lineup_data: game_lineup.lineup_data,
          updated_at: game_lineup.updated_at
        }
      end
    end
  end
end
