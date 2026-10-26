class Api::V1::HomeController < Api::V1::BaseController
  def summary
    competition = Competition.find(params[:competition_id])

    # ノーゲームは勝敗・成績に入れない（台帳 D-11）。消化試合数・直近試合にも数えない
    counted_games = competition.games.where(status: "confirmed").excluding_no_game
    # 直近試合（最新5件 confirmed）
    recent_games = counted_games
      .order(real_date: :desc)
      .limit(5)
      .includes(:home_team, :visitor_team, :stadium)

    # シーズン進行
    total_games = counted_games.count
    season_progress = { completed: total_games, total: 143 }

    # 成績サマリー
    batting_stats = BattingStatsCalculator.new(competition).calculate
      .sort_by { |s| -s[:batting_average].to_f }.first(3)
    pitching_stats = PitchingStatsCalculator.new(competition).calculate
      .sort_by { |s| s[:era].to_f }.first(3)
    team_stats = TeamStatsCalculator.new(competition).calculate.first

    render json: {
      season_progress: season_progress,
      recent_games: recent_games.map { |g| game_summary(g) },
      batting_top3: batting_stats.map { |player|
        player.merge(
          hr: player[:home_runs],
          batting_average: format("%.3f", player[:batting_average].to_f).sub(/^0/, "")
        )
      },
      pitching_top3: pitching_stats.map { |pitcher|
        pitcher.merge(era: format("%.2f", pitcher[:era].to_f))
      },
      team_summary: team_stats
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Competition not found" }, status: :not_found
  end

  private

  def game_summary(game)
    {
      id: game.id,
      real_date: game.real_date,
      home_team: game.home_team&.name,
      visitor_team: game.visitor_team&.name,
      home_score: game.home_score,
      visitor_score: game.visitor_score
    }
  end
end
