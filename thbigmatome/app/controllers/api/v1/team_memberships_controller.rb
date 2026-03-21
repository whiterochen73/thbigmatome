module Api
  module V1
    class TeamMembershipsController < Api::V1::BaseController
      include TeamAccessible
      before_action :authorize_team_access!

      def index
        team = Team.find(params[:team_id])
        team_memberships = team.team_memberships.preload(:player)

        if params[:filter] == "starter_eligible"
          team_memberships = team_memberships
            .where.not(selected_cost_type: "relief_only_cost")
            .joins(player: :player_cards)
            .where(player_cards: { card_type: "pitcher", is_relief_only: false })
            .distinct
        end

        output =
          team_memberships.map do |member|
            player = member.player
            {
              id: member.id,
              name: "#{player.number} #{player.name}",
              player_id: player.id
            }
          end

        render json: output
      end
    end
  end
end
