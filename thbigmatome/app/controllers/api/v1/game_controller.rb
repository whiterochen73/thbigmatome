class Api::V1::GameController < ApplicationController
  def show
    season_schedule = SeasonSchedule.find(params[:id])

    season = season_schedule.season
    team = season.team
    if season.nil?
      render json: { error: 'Season not initialized for this team' }, status: :not_found
      return
    end

    game_result = nil
    if season_schedule.date < Date.today && season_schedule.score.present? && season_schedule.oppnent_score.present?
      result = if season_schedule.score > season_schedule.oppnent_score
                 'win'
               elsif season_schedule.score < season_schedule.oppnent_score
                 'lose'
               else
                 'draw'
               end
      game_result = {
        opponent_short_name: season_schedule.opponent_team&.name, # Using full name for now
        score: "#{season_schedule.score}-#{season_schedule.oppnent_score}",
        result: result
      }
    end

    render json: {
      team_id: team.id,
      team_name: team.name,
      season_id: season.id,
      game_date: season_schedule.date,
      game_number:
      season_schedule.game_number ||
        season.season_schedules
        .where(date_type: ['game_day', 'interleague_game_day'])
        .where(['date < :date', { date: season_schedule.date }])
        .count + 1,
      announced_starter_id: season_schedule.announced_starter&.id,
      stadium: season_schedule.stadium,
      home_away: season_schedule.home_away,
      designated_hitter_enabled: season_schedule.designated_hitter_enabled,
      score: season_schedule.score,
      opponent_score: season_schedule.oppnent_score,
      opponent_team_id: season_schedule.opponent_team&.id,
      opponent_team: season_schedule.opponent_team&.name,
      winning_pitcher_id: season_schedule.winning_pitcher&.id,
      losing_pitcher_id: season_schedule.losing_pitcher&.id,
      save_pitcher_id: season_schedule.save_pitcher&.id,
      scoreboard: season_schedule.scoreboard,
      game_result: game_result
    }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Team or Season not found' }, status: :not_found
  rescue ArgumentError
    render json: { error: 'Invalid date format' }, status: :bad_request
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
    render json: { error: 'Game not found' }, status: :not_found
  end

  private

  def game_params
    # フロントエンドから送られてくるパラメータ。typoしている項目(opponent)はここで修正する
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
      scoreboard: { home: [], away: [] }
    )

    permitted_params[:oppnent_score] = permitted_params.delete(:opponent_score) if permitted_params.key?(:opponent_score)
    permitted_params[:oppnent_team_id] = permitted_params.delete(:opponent_team_id) if permitted_params.key?(:opponent_team_id)

    permitted_params
  end
end
