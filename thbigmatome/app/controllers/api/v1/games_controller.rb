class Api::V1::GamesController < Api::V1::BaseController
  def index
    games = Game.includes(:game_record).order(id: :desc)
    games = games.where(competition_id: params[:competition_id]) if params[:competition_id].present?
    if params[:from].present? && params[:to].present?
      games = games.where(real_date: params[:from]..params[:to])
    end
    render json: games, each_serializer: GameSerializer
  end

  def show
    game = Game.includes(:at_bats).find(params[:id])
    render json: game, serializer: GameSerializer
  end
end
