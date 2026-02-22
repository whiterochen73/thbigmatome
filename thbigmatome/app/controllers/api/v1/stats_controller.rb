class Api::V1::StatsController < Api::V1::BaseController
  def batting
    competition = Competition.find(params[:competition_id])
    stats = BattingStatsCalculator.new(competition).calculate
    render json: { batting_stats: stats }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Competition not found" }, status: :not_found
  end

  def pitching
    competition = Competition.find(params[:competition_id])
    stats = PitchingStatsCalculator.new(competition).calculate
    render json: { pitching_stats: stats }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Competition not found" }, status: :not_found
  end

  def team
    competition = Competition.find(params[:competition_id])
    stats = TeamStatsCalculator.new(competition).calculate
    render json: { team_stats: stats }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Competition not found" }, status: :not_found
  end
end
