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

  def create
    game = Game.new(game_params)
    if game.save
      render json: game, serializer: GameSerializer, status: :created
    else
      render json: { errors: game.errors.full_messages }, status: :unprocessable_content
    end
  end

  def confirm
    game = Game.find(params[:id])
    if game.draft?
      game.at_bats.draft.update_all(status: :confirmed)
      if game.update(status: "confirmed")
        render json: {
          game: GameSerializer.new(game).as_json,
          confirmed_count: game.at_bats.confirmed.count
        }
      else
        render json: { errors: game.errors.full_messages }, status: :unprocessable_content
      end
    else
      render json: { error: "Game is not in draft status" }, status: :unprocessable_content
    end
  end

  private

  def game_params
    params.require(:game).permit(:competition_id, :home_team_id, :visitor_team_id, :real_date, :stadium_id, :status, :source)
  end
end
