class Api::V1::LeagueSeasonsController < ApplicationController
  before_action :set_league_season, only: [:show, :update, :destroy, :generate_schedule]

  def index
    @league_seasons = LeagueSeason.all
    render json: @league_seasons
  end

  def show
    render json: @league_season
  end

  def create
    @league_season = LeagueSeason.new(league_season_params)

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
    render json: { message: 'Schedule generated successfully' }, status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_league_season
    @league_season = LeagueSeason.find(params[:id])
  end

  def league_season_params
    params.require(:league_season).permit(:league_id, :name, :start_date, :end_date, :status)
  end
end
