class Api::V1::TeamPlayersController < Api::V1::BaseController
  include TeamAccessible

  before_action :set_team
  before_action :authorize_team_access!

  def index
    cost_list_id = params[:cost_list_id]
    players = @team.players.includes(:cost_players, player_cards: :player_card_defenses)
    render json: players, each_serializer: TeamPlayerSerializer, team: @team, cost_list_id: cost_list_id
  end

  def create
    player_params = params.require(:players)
    cost_list_id = params[:cost_list_id]&.to_i
    incoming_player_ids = player_params.map { |p| p[:player_id] }
    commissioner = current_user.commissioner?
    commissioner_warnings = []

    ActiveRecord::Base.transaction do
      # Delete memberships for players who are no longer in the team
      @team.team_memberships.where.not(player_id: incoming_player_ids).destroy_all

      # Upsert memberships for incoming players
      player_params.each do |p|
        membership = @team.team_memberships.find_or_initialize_by(player_id: p[:player_id])
        membership.skip_commissioner_validation = true if commissioner
        membership.update!(
          selected_cost_type: p[:selected_cost_type],
          excluded_from_team_total: p[:excluded_from_team_total] || false,
          display_name: p[:display_name].presence
        )
      end

      # Validate team total cost limit (200 fixed) after all memberships are updated
      @team.team_memberships.reload
      if cost_list_id
        unless @team.validate_team_total_cost(cost_list_id)
          if commissioner
            commissioner_warnings << @team.errors.full_messages.first
          else
            raise ActiveRecord::RecordInvalid.new(@team)
          end
        end
      end
    end

    render json: { message: "Team members updated successfully", warnings: commissioner_warnings }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record&.errors&.full_messages&.join(", ") || e.message }, status: :unprocessable_content
  end

  private

  def set_team
    @team = Team.find(params[:team_id])
  end
end
