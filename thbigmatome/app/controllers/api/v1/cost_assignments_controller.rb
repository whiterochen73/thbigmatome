module Api
  module V1
    class CostAssignmentsController < ApplicationController
      def index
        @cost_id = params[:cost_id]
        @players = Player.order(:id).includes(:player_types).preload(:cost_players)

        players_with_cost = @players.map do |player|
          player_data = player.as_json(
            include: {
              player_types: { only: [:id, :name] }
            },
            except: [:created_at, :updated_at]
          )

          player_data[:normal_cost] = player.cost_players.find { |cp| cp.cost_id == @cost_id.to_i }&.normal_cost
          player_data[:relief_only_cost] = player.cost_players.find { |cp| cp.cost_id == @cost_id.to_i }&.relief_only_cost
          player_data[:pitcher_only_cost] = player.cost_players.find { |cp| cp.cost_id == @cost_id.to_i }&.pitcher_only_cost
          player_data[:fielder_only_cost] = player.cost_players.find { |cp| cp.cost_id == @cost_id.to_i }&.fielder_only_cost
          player_data[:two_way_cost] = player.cost_players.find { |cp| cp.cost_id == @cost_id.to_i }&.two_way_cost
          player_data
        end
        render json: players_with_cost
      end

      def create
        cost = Cost.find(cost_assignment_params[:cost_id])
        cost_assignment_params[:players].each do |player_params|
            cost_player = cost.cost_players.find_or_initialize_by(player_id: player_params[:player_id])
            cost_player[:normal_cost] = player_params[:normal_cost]
            cost_player[:relief_only_cost] = player_params[:relief_only_cost]
            cost_player[:pitcher_only_cost] = player_params[:pitcher_only_cost]
            cost_player[:fielder_only_cost] = player_params[:fielder_only_cost]
            cost_player[:two_way_cost] = player_params[:two_way_cost]
            cost_player.save!
         end
      end

      def cost_assignment_params
        params.require(:assignments).permit(:cost_id, players: [:player_id, :normal_cost, :relief_only_cost, :pitcher_only_cost, :fielder_only_cost, :two_way_cost])
      end
    end
  end
end
