class Api::V1::Commissioner::LeaguesController < Api::V1::Commissioner::BaseController
  before_action :set_league, only: [:show, :update, :destroy]

  def index
    leagues = League.all
    render json: leagues
  end

  def show
    render json: @league
  end

  def create
    league = League.new(league_params)
    if league.save
      render json: league, status: :created
    else
      render json: league.errors, status: :unprocessable_entity
    end
  end

  def update
    if @league.update(league_params)
      render json: @league
    else
      render json: @league.errors, status: :unprocessable_entity
    end
  end

  def destroy
    if @league.destroy
      head :no_content
    else
      render json: @league.errors, status: :unprocessable_entity
    end
  end

  private

  def set_league
    @league = League.find(params[:id])
  end

  def league_params
    params.require(:league).permit(:name, :num_teams, :num_games, :active)
  end
end
