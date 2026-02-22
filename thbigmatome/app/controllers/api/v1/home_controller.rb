class Api::V1::HomeController < Api::V1::BaseController
  def summary
    competition = Competition.find(params[:competition_id])

    # 直近試合（最新5件 confirmed）
    recent_games = competition.games
      .where(status: "confirmed")
      .order(real_date: :desc)
      .limit(5)
      .includes(:home_team, :visitor_team, :stadium)

    # シーズン進行
    total_games = competition.games.where(status: "confirmed").count
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
      batting_top3: batting_stats,
      pitching_top3: pitching_stats,
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
