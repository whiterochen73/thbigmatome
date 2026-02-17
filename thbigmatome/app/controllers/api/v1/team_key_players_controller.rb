module Api
  module V1
    class TeamKeyPlayersController < Api::V1::BaseController
      def create
        team = Team.find(params[:team_id])
        season = team.season
        if season.nil?
          render json: { error: "Season not initialized for this team" }, status: :bad_request
          return
        end

        key_player_id = params[:key_player_id] # Can be null for no key player

        # Rule: Only one key player can be selected on the first day of the season.
        # This implies a 'key_player_id' column on the Season model.
        # Let's add it to the Season model first.
        start_date = season.season_schedules.minimum(:date)

        if season.current_date != start_date # Assuming schedule is associated with season
          render json: { error: "キープレイヤーはシーズン初日のみ設定可能です。" }, status: :bad_request
          return
        end

        # Update the season's key_player_id
        season.update!(key_player_id: key_player_id)

        render json: { message: "Key player set successfully" }, status: :ok
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: e.message }, status: :not_found
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
    end
  end
end
