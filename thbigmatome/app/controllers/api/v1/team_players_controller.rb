class Api::V1::TeamPlayersController < ApplicationController
  before_action :set_team

  def index
    cost_list_id = params[:cost_list_id]
    players = @team.players
    render json: players, each_serializer: TeamPlayerSerializer, team: @team, cost_list_id: cost_list_id
  end

  def create
    player_params = params.require(:players)
    cost_list_id = params[:cost_list_id]&.to_i
    incoming_player_ids = player_params.map { |p| p[:player_id] }

    ActiveRecord::Base.transaction do
      # Delete memberships for players who are no longer in the team
      @team.team_memberships.where.not(player_id: incoming_player_ids).destroy_all

      # Upsert memberships for incoming players
      player_params.each do |p|
        membership = @team.team_memberships.find_or_initialize_by(player_id: p[:player_id])
        membership.update!(
          selected_cost_type: p[:selected_cost_type],
          excluded_from_team_total: p[:excluded_from_team_total] || false
        )
      end

      # Validate cost limits after all memberships are updated
      @team.team_memberships.reload
      unless @team.validate_minimum_players
        raise ActiveRecord::RecordInvalid.new(@team)
      end

      if cost_list_id
        unless @team.validate_cost_within_limit(cost_list_id)
          raise ActiveRecord::RecordInvalid.new(@team)
        end
      end
    end

    render json: { message: "Team members updated successfully" }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record&.errors&.full_messages&.join(", ") || e.message }, status: :unprocessable_entity
  end

  private

  def set_team
    @team = Team.find(params[:team_id])
  end
end
