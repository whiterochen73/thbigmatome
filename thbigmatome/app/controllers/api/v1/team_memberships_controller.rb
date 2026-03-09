module Api
  module V1
    class TeamMembershipsController < Api::V1::BaseController
      def index
        team = Team.find(params[:team_id])
        team_memberships = team.team_memberships.preload(:player)

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
