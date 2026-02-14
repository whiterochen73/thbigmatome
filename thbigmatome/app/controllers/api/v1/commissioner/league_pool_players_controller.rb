class Api::V1::Commissioner::LeaguePoolPlayersController < ApplicationController
  before_action :set_league_season
  before_action :set_league_pool_player, only: [:destroy]

  def index
    @pool_players = @league_season.pool_players

    # コストによるフィルタリング
    if params[:cost_rank].present?
      @pool_players = filter_by_cost_rank(@pool_players, params[:cost_rank])
    end

    render json: @pool_players
  end

  def create
    @league_pool_player = @league_season.league_pool_players.build(league_pool_player_params)

    if @league_pool_player.save
      render json: @league_pool_player, status: :created
    else
      render json: @league_pool_player.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @league_pool_player.destroy
    head :no_content
  end

  private

  def set_league_season
    @league_season = LeagueSeason.find(params[:league_season_id])
  end

  def set_league_pool_player
    @league_pool_player = @league_season.league_pool_players.find(params[:id])
  end

  def league_pool_player_params
    params.require(:league_pool_player).permit(:player_id)
  end

  def filter_by_cost_rank(players, cost_rank)
    case cost_rank.upcase
    when 'A'
      players.joins(cost_players: :cost).where('costs.normal_cost >= ?', 8)
    when 'B'
      players.joins(cost_players: :cost).where('costs.normal_cost BETWEEN ? AND ?', 5, 7)
    when 'C'
      players.joins(cost_players: :cost).where('costs.normal_cost <= ?', 4)
    else
      players # 不明なランクの場合はフィルタリングしない
    end
  end
end
