class Api::V1::TeamPlayersController < ApplicationController
  before_action :set_team

  def index
    cost_list_id = params[:cost_list_id]
    players = @team.players
    render json: players, each_serializer: TeamPlayerSerializer, team: @team, cost_list_id: cost_list_id
  end

  def create
    player_params = params.require(:players)
    incoming_player_ids = player_params.map { |p| p[:player_id] }

    ActiveRecord::Base.transaction do
      # Delete memberships for players who are no longer in the team
      @team.team_memberships.where.not(player_id: incoming_player_ids).destroy_all

      # Upsert memberships for incoming players
      player_params.each do |p|
        membership = @team.team_memberships.find_or_initialize_by(player_id: p[:player_id])
        membership.update!(selected_cost_type: p[:selected_cost_type])
      end
    end

    render json: { message: 'Team members updated successfully' }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_team
    @team = Team.find(params[:team_id])
  end
end
