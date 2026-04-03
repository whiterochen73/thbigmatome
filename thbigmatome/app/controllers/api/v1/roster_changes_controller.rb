module Api
  module V1
    class RosterChangesController < BaseController
      include TeamAccessible

      before_action :set_team
      before_action :authorize_team_access!

      def index
        since_date = params[:since].presence || "1900-01-01"
        season_id  = params[:season_id]

        if season_id.blank?
          return render json: { error: "season_id is required" }, status: :unprocessable_entity
        end

        result = RosterChangeService.new(@team, season_id, since_date).call
        render json: result
      rescue ArgumentError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def set_team
        @team = Team.find(params[:team_id])
      end
    end
  end
end
