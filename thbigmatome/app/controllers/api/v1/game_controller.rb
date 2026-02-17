class Api::V1::GameController < Api::V1::BaseController
  def show
    season_schedule = SeasonSchedule.find(params[:id])

    season = season_schedule.season
    team = season.team
    if season.nil?
      render json: { error: "Season not initialized for this team" }, status: :not_found
      return
    end

    render json: {
      team_id: team.id,
      team_name: team.name,
      season_id: season.id,
      game_date: season_schedule.date,
      game_number: season_schedule.calculated_game_number,
      announced_starter_id: season_schedule.announced_starter&.id,
      stadium: season_schedule.stadium,
      home_away: season_schedule.home_away,
      designated_hitter_enabled: season_schedule.designated_hitter_enabled,
      score: season_schedule.score,
      opponent_score: season_schedule.opponent_score,
      opponent_team_id: season_schedule.opponent_team&.id,
      opponent_team: season_schedule.opponent_team&.name,
      winning_pitcher_id: season_schedule.winning_pitcher&.id,
      losing_pitcher_id: season_schedule.losing_pitcher&.id,
      save_pitcher_id: season_schedule.save_pitcher&.id,
      scoreboard: season_schedule.scoreboard,
      starting_lineup: season_schedule.starting_lineup,
      opponent_starting_lineup: season_schedule.opponent_starting_lineup,
      game_result: season_schedule.date < Date.today ? season_schedule.game_result_hash : nil
    }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Team or Season not found" }, status: :not_found
  rescue ArgumentError
    render json: { error: "Invalid date format" }, status: :bad_request
  end

  def update
    season_schedule = SeasonSchedule.find(params[:id])

    update_params = game_params
    if season_schedule.update(update_params)
      render json: season_schedule, status: :ok
    else
      render json: { errors: season_schedule.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Game not found" }, status: :not_found
  end

  private

  def game_params
    # フロントエンドから送られてくるパラメータ
    permitted_params = params.permit(
      :announced_starter_id,
      :stadium,
      :home_away,
      :designated_hitter_enabled,
      :score,
      :opponent_score,
      :opponent_team_id,
      :winning_pitcher_id,
      :losing_pitcher_id,
      :save_pitcher_id,
      scoreboard: { home: [], away: [] },
      starting_lineup: [ :player_id, :position, :order ],
      opponent_starting_lineup: [ :player_id, :position, :order ]
    )

    permitted_params
  end
end
