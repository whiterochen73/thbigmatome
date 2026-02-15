class Api::V1::Commissioner::LeagueSeasonsController < Api::V1::Commissioner::BaseController
  before_action :set_league
  before_action :set_league_season, only: [ :show, :update, :destroy, :generate_schedule ]

  def index
    @league_seasons = @league.league_seasons
    render json: @league_seasons
  end

  def show
    render json: @league_season
  end

  def create
    @league_season = @league.league_seasons.build(league_season_params)

    if @league_season.save
      render json: @league_season, status: :created
    else
      render json: @league_season.errors, status: :unprocessable_entity
    end
  end

  def update
    if @league_season.update(league_season_params)
      render json: @league_season
    else
      render json: @league_season.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @league_season.destroy
    head :no_content
  end

  def generate_schedule
    @league_season.generate_schedule
    render json: { message: "Schedule generated successfully" }, status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_league
    @league = League.find(params[:league_id])
  end

  def set_league_season
    @league_season = @league.league_seasons.find(params[:id])
  end

  def league_season_params
    params.require(:league_season).permit(:name, :start_date, :end_date, :status)
  end
end
