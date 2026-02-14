class Api::V1::Commissioner::LeagueGamesController < ApplicationController
  before_action :set_league_season
  before_action :set_league_game, only: [:show]

  def index
    @league_games = @league_season.league_games
    render json: @league_games
  end

  def show
    render json: @league_game
  end

  private

  def set_league_season
    @league_season = LeagueSeason.find(params[:league_season_id])
  end

  def set_league_game
    @league_game = @league_season.league_games.find(params[:id])
  end
end
