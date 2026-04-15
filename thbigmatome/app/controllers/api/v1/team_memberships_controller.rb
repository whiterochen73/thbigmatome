module Api
  module V1
    class TeamMembershipsController < Api::V1::BaseController
      include TeamAccessible
      before_action :authorize_team_access!

      def index
        team = Team.find(params[:team_id])
        team_memberships = team.team_memberships.preload(:player, player_card: :card_set)

        if params[:filter] == "starter_eligible"
          team_memberships = team_memberships
            .where.not(selected_cost_type: "relief_only_cost")
            .joins(player: :player_cards)
            .merge(PlayerCard.can_pitch.where(is_relief_only: false))
            .distinct
        end

        output =
          team_memberships.map do |member|
            player = member.player
            pc = member.player_card
            {
              id: member.id,
              name: "#{player.number} #{player.name}",
              number: player.number,
              player_id: player.id,
              player_card_id: member.player_card_id,
              player_card_info: pc ? { id: pc.id, card_type: pc.card_type, card_set_name: pc.card_set.name, card_set_id: pc.card_set_id } : nil
            }
          end

        render json: output
      end
    end
  end
end
