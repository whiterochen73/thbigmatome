module Api
  module V1
    class CostAssignmentsController < Api::V1::BaseController
      def index
        @cost_id = params[:cost_id].to_i
        @players = Player.order(:id).preload(:cost_players, player_cards: :player_types)

        rows = []

        @players.each do |player|
          base_cp = player.cost_players.find { |cp| cp.cost_id == @cost_id && cp.player_card_id.nil? }

          # Base entry (player_card_id=nil)
          rows << build_row(player, nil, base_cp)

          # Variant entries: cards with non-nil variant (自動判定, ハードコード不要)
          variant_cards = player.player_cards.select { |pc| pc.variant.present? }
          variant_cards.each do |card|
            variant_cp = player.cost_players.find { |cp| cp.cost_id == @cost_id && cp.player_card_id == card.id }
            rows << build_row(player, card, variant_cp)
          end
        end

        render json: rows
      end

      def create
        cost = Cost.find(cost_assignment_params[:cost_id])
        ActiveRecord::Base.transaction do
          cost_assignment_params[:players].each do |player_params|
            player_card_id = player_params[:player_card_id].presence
            cost_player = cost.cost_players.find_or_initialize_by(
              player_id: player_params[:player_id],
              player_card_id: player_card_id
            )
            cost_player[:normal_cost] = player_params[:normal_cost]
            cost_player[:relief_only_cost] = player_params[:relief_only_cost]
            cost_player[:pitcher_only_cost] = player_params[:pitcher_only_cost]
            cost_player[:fielder_only_cost] = player_params[:fielder_only_cost]
            cost_player[:two_way_cost] = player_params[:two_way_cost]
            cost_player.save!
          end
        end
      end

      private

      # card: nil=ベースエントリ, PlayerCard=バリエーションエントリ
      def build_row(player, card, cost_player)
        player_types = player.player_cards
          .flat_map(&:player_types)
          .uniq(&:id)
          .map { |pt| { id: pt.id, name: pt.name } }

        available_cost_types = card.nil? ? player.available_cost_types : player.available_cost_types_for_card(card)

        {
          id: player.id,
          name: player.name,
          number: player.number,
          player_types: player_types,
          available_cost_types: available_cost_types,
          player_card_id: card&.id,
          variant: card&.variant,
          card_label: card&.card_label,
          normal_cost: cost_player&.normal_cost,
          relief_only_cost: cost_player&.relief_only_cost,
          pitcher_only_cost: cost_player&.pitcher_only_cost,
          fielder_only_cost: cost_player&.fielder_only_cost,
          two_way_cost: cost_player&.two_way_cost
        }
      end

      def cost_assignment_params
        params.require(:assignments).permit(:cost_id, players: [ :player_id, :player_card_id, :normal_cost, :relief_only_cost, :pitcher_only_cost, :fielder_only_cost, :two_way_cost ])
      end
    end
  end
end
