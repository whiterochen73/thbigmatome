module Api
  module V1
    class TeamMembershipsController < ApplicationController
      def index
        team = Team.find(params[:team_id])
        team_memberships = team.team_memberships.preload(:player)

        output =
          team_memberships.map do |member|
            { id: member.id, name: "#{member.player.number} #{member.player.name}" }
          end

        render json: output
      end
    end
  end
end
