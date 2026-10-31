module Api
  module V1
    class TeamKeyPlayersController < Api::V1::BaseController
      include TeamAccessible
      before_action :authorize_team_access!

      def create
        team = Team.find(params[:team_id])
        season = team.season
        if season.nil?
          render json: { error: "Season not initialized for this team" }, status: :bad_request
          return
        end

        key_player_id = params[:key_player_id] # Can be null for no key player

        # Rule: キープレイヤーはシーズン初日にだけ設定できる。現在日が日程から導かれるようになったので（SeasonCurrentRange）、
        # 「初日」は「まだ結果が 1 件も入っていない（今の範囲が日程の最初の日から始まっている）間」と読む
        start_date = season.season_schedules.minimum(:date)

        if start_date.nil? || season.current_range&.start_date != start_date
          render json: { error: "キープレイヤーはシーズン初日のみ設定可能です。" }, status: :bad_request
          return
        end

        # Update the season's key_player_id
        season.update!(key_player_id: key_player_id)

        render json: { message: "Key player set successfully" }, status: :ok
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: e.message }, status: :not_found
      rescue => e
        render json: { error: e.message }, status: :unprocessable_content
      end
    end
  end
end
