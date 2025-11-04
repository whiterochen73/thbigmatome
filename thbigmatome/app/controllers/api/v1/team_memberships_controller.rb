module Api
  module V1
    class TeamMembershipsController < ApplicationController
      def index
        team = Team.find(params[:team_id])
        team_memberships = team.team_memberships.preload(:player)

        output =
          team_memberships.map do |member|
            player = member.player
            {
              id: member.id,
              name: "#{player.number} #{player.name}",
              player_id: player.id,
              defense_p: player.defense_p,
              defense_c: player.defense_c,
              defense_1b: player.defense_1b,
              defense_2b: player.defense_2b,
              defense_3b: player.defense_3b,
              defense_ss: player.defense_ss,
              defense_of: player.defense_of,
              defense_lf: player.defense_lf,
              defense_cf: player.defense_cf,
              defense_rf: player.defense_rf,
              throwing_c: player.throwing_c,
              throwing_of: player.throwing_of,
              throwing_lf: player.throwing_lf,
              throwing_cf: player.throwing_cf,
              throwing_rf: player.throwing_rf,
            }
          end

        render json: output
      end
    end
  end
end
