require "open3"

class Api::V1::GamesController < Api::V1::BaseController
  def index
    games = Game.all.order(id: :desc)
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
      render json: { errors: game.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def confirm
    game = Game.find(params[:id])
    if game.draft?
      if game.update(status: "confirmed")
        render json: game, serializer: GameSerializer
      else
        render json: { errors: game.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: "Game is not in draft status" }, status: :unprocessable_entity
    end
  end

  def import_log
    log_text = params[:log]
    return render json: { error: "log parameter required" }, status: :bad_request if log_text.blank?

    # パーサー呼び出し
    parser_path = Rails.root.join("lib", "irc_parser", "parse_log.py")
    stdout, stderr, status = Open3.capture3("python3", parser_path.to_s, stdin_data: log_text)

    unless status.success?
      return render json: { error: "Parser error: #{stderr.truncate(200)}" }, status: :unprocessable_entity
    end

    parsed = JSON.parse(stdout)

    # draft Gameを作成（raw_logを保存）
    game_params_for_import = {
      competition_id: params[:competition_id],
      home_team_id: params[:home_team_id],
      visitor_team_id: params[:visitor_team_id],
      real_date: params[:real_date],
      stadium_id: params[:stadium_id] || Stadium.first&.id,
      status: "draft",
      source: "log_import",
      raw_log: log_text
    }

    game = Game.new(game_params_for_import)
    if game.save
      render json: {
        game: GameSerializer.new(game).as_json,
        parsed_at_bats: parsed,
        at_bat_count: parsed["at_bats"]&.length || 0
      }, status: :created
    else
      render json: { errors: game.errors.full_messages }, status: :unprocessable_entity
    end
  rescue JSON::ParserError => e
    render json: { error: "JSON parse error: #{e.message}" }, status: :unprocessable_entity
  end

  private

  def game_params
    params.require(:game).permit(:competition_id, :home_team_id, :visitor_team_id, :real_date, :stadium_id, :status, :source)
  end
end
