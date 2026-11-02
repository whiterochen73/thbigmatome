class Api::V1::GameController < Api::V1::BaseController
  def show
    season_schedule = SeasonSchedule.find(params[:id])

    season = season_schedule.season
    team = season.team
    if season.nil?
      render json: { error: "Season not initialized for this team" }, status: :not_found
      return
    end

    year = season_schedule.date.year
    competition_entry = CompetitionEntry.joins(:competition)
                                        .where(team_id: team.id)
                                        .where(competitions: { year: year, competition_type: "league_pennant" })
                                        .first
    competition_id = competition_entry&.competition_id

    render json: {
      team_id: team.id,
      team_name: team.name,
      season_id: season.id,
      game_date: season_schedule.date,
      game_number: season_schedule.calculated_game_number,
      announced_starter_id: season_schedule.announced_starter&.id,
      competition_id: competition_id,
      stadium: season_schedule.stadium,
      real_date: season_schedule.real_date,
      real_start_time: season_schedule.real_start_time,
      venue: season_schedule.venue,
      game_log: season_schedule.game_log,
      home_away: season_schedule.home_away,
      designated_hitter_enabled: season_schedule.designated_hitter_enabled,
      score: season_schedule.score,
      opponent_score: season_schedule.opponent_score,
      no_game: season_schedule.no_game,
      opponent_team_id: season_schedule.opponent_team&.id,
      opponent_team: season_schedule.opponent_team&.name,
      **head_names(season_schedule),
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
      # 得点は保存済み。投手の判定の作り直しだけが失敗した時は、警告で知らせる（画面が「後で作り直しが必要」と出す）
      warnings = []
      if season_schedule.pitcher_rebuild_error
        warnings << "得点は保存しましたが、投手の判定の作り直しに失敗しました。後で作り直しが必要です（登板記録の区分が古いままです）"
      end
      render json: season_schedule.as_json.merge("warnings" => warnings).merge(head_names(season_schedule).stringify_keys), status: :ok
    else
      render json: { errors: season_schedule.errors.full_messages }, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Game not found" }, status: :not_found
  end

  private

  # 試合日ページの上の段に出す名前。相手は短縮形（無ければ正式名）、予告先発は選手名（背番号なし）。決まっていなければ nil
  # opponent_schedule_id は、相手名を押した時の飛び先（相手のシーズンの同じ日の試合日ページ）。無ければ nil
  def head_names(season_schedule)
    opponent = season_schedule.opponent_team
    {
      opponent_team_short_name: opponent && (opponent.short_name.presence || opponent.name),
      announced_starter_name: season_schedule.announced_starter&.player&.name,
      opponent_schedule_id: opponent_schedule_id(season_schedule, opponent)
    }
  end

  # 相手のシーズンの、同じ日の、相手が自チームになっている日程の id（同じ試合の反対側）。
  # 相手の同じ日が別のチームとの試合・相手未定の日は、同じ試合とは言えないので nil（画面は相手のカレンダーへ飛ばす）。
  def opponent_schedule_id(season_schedule, opponent)
    return nil unless opponent

    opponent_season = Season.find_by(team_id: opponent.id)
    return nil unless opponent_season

    opponent_season.season_schedules
                   .where(date: season_schedule.date, opponent_team_id: season_schedule.season.team_id)
                   .order(:id)
                   .pick(:id)
  end

  def game_params
    # フロントエンドから送られてくるパラメータ
    permitted_params = params.permit(
      :announced_starter_id,
      :stadium,
      :real_date,
      :real_start_time,
      :venue,
      :game_log,
      :home_away,
      :designated_hitter_enabled,
      :score,
      :opponent_score,
      :no_game,
      :opponent_team_id,
      scoreboard: { home: [], away: [] },
      starting_lineup: [ :player_id, :position, :order ],
      opponent_starting_lineup: [ :player_id, :position, :order ]
    )

    permitted_params
  end
end
