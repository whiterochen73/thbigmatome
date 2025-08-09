class Api::V1::TeamPlayersController < ApplicationController
  before_action :set_team

  def index
    cost_list_id = params[:cost_list_id]
    players = @team.players
    render json: players, each_serializer: TeamPlayerSerializer, team: @team, cost_list_id: cost_list_id
  end

  def create
    player_params = params.require(:players)

    ActiveRecord::Base.transaction do
      @team.team_memberships.destroy_all
      player_params.each do |p|
        @team.team_memberships.create!(
          player_id: p[:player_id],
          selected_cost_type: p[:selected_cost_type]
        )
      end
    end

    render json: { message: 'Team members updated successfully' }, status: :ok
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_team
    @team = Team.find(params[:team_id])
  end
end
