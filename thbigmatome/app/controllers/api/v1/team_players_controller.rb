class Api::V1::TeamPlayersController < Api::V1::BaseController
  include TeamAccessible

  before_action :set_team
  before_action :authorize_team_access!

  # GET /teams/:team_id/team_players?cost_list_id=&target_date=YYYY-MM-DD&phase=pre_game|in_game|post_game
  # target_date を省くと「今の」チーム編成（在籍中の写し）。付けるとその時点（日付 + 区分）の在籍・契約・カード・コスト除外・表示名を
  # チーム編成の変更記録から導いて返す（cmd_1784 段2）。応答の形は同じ。
  def index
    cost_list_id = params[:cost_list_id]
    if params[:target_date].present?
      phase = RosterState.parse_phase(params[:phase])
      date = Date.parse(params[:target_date])
      state = RosterState.new(@team, memberships: @team.all_team_memberships.preload(:team_membership_changes, :player, player_card: :card_set).to_a)
      entries = state.at(date, phase)
      views = state.memberships.select { |tm| entries.fetch(tm.id).on_team }.index_by(&:player_id).transform_values { |tm| state.view(tm, entries.fetch(tm.id)) }
      players = Player.where(id: views.keys).includes(:cost_players, player_cards: :player_card_defenses)
      render json: players, each_serializer: TeamPlayerSerializer, team: @team, cost_list_id: cost_list_id, membership_views: views
    else
      players = @team.players.includes(:cost_players, player_cards: :player_card_defenses, team_memberships: { player_card: :card_set })
      render json: players, each_serializer: TeamPlayerSerializer, team: @team, cost_list_id: cost_list_id
    end
  rescue Date::Error
    render json: { error: "Invalid date format" }, status: :bad_request
  rescue ArgumentError => e
    raise unless e.message.start_with?("invalid phase")

    render json: { error: "Invalid phase" }, status: :bad_request
  end

  # POST /teams/:team_id/team_players
  # params: players（全員分。無い選手は放出）, cost_list_id, target_date（省略時は現在日カーソル）, phase（省略時は pre_game）
  # シーズンのあるチームは、送られた値と target_date 時点の状態の差を変更記録（登録・契約・放出）として足す（TeamMembershipWriter）。
  # シーズンの無いチームは日付が無いので、これまでどおり行を直接書く。
  def create
    player_params = params.require(:players)
    cost_list_id = params[:cost_list_id]&.to_i
    commissioner = current_user.commissioner?

    if @team.season
      create_with_changes(player_params, cost_list_id, commissioner)
    else
      create_without_season(player_params, cost_list_id, commissioner)
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record&.errors&.full_messages&.join(", ") || e.message }, status: :unprocessable_content
  rescue TeamMembershipWriter::Rejected => e
    render json: { error: e.message, violations: e.violations.map(&:to_h) }, status: :unprocessable_content
  rescue Date::Error
    render json: { error: "Invalid date format" }, status: :bad_request
  rescue ArgumentError => e
    raise unless e.message.start_with?("invalid phase")

    render json: { error: "Invalid phase" }, status: :bad_request
  end

  private

  def create_with_changes(player_params, cost_list_id, commissioner)
    date = params[:target_date].present? ? Date.parse(params[:target_date]) : @team.season.current_date
    phase = RosterState.parse_phase(params[:phase])

    writer = TeamMembershipWriter.new(team: @team, user: current_user, commissioner: commissioner, cost_list_id: cost_list_id)
    result = writer.update!(player_params, date: date, phase: phase)

    render json: { message: "Team members updated successfully", warnings: result.warnings }, status: :ok
  end

  # シーズンの無いチーム: 日付も昇降格の記録も離脱も無いので、行を直接書き換える（放出は行の削除）
  def create_without_season(player_params, cost_list_id, commissioner)
    incoming_player_ids = player_params.map { |p| p[:player_id] }
    commissioner_warnings = []

    ActiveRecord::Base.transaction do
      # Delete memberships for players who are no longer in the team
      @team.all_team_memberships.where.not(player_id: incoming_player_ids).destroy_all

      # Upsert memberships for incoming players
      player_params.each do |p|
        membership = @team.all_team_memberships.find_or_initialize_by(player_id: p[:player_id])
        membership.skip_commissioner_validation = true if commissioner
        membership.update!(
          selected_cost_type: p[:selected_cost_type],
          excluded_from_team_total: p[:excluded_from_team_total] || false,
          display_name: p[:display_name].presence,
          player_card_id: p[:player_card_id].presence,
          on_team: true
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
  end

  def set_team
    @team = Team.find(params[:team_id])
  end
end
