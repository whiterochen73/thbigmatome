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
      game.at_bats.draft.update_all(status: :confirmed)
      if game.update(status: "confirmed")
        render json: {
          game: GameSerializer.new(game).as_json,
          confirmed_count: game.at_bats.confirmed.count
        }
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
    unless game.save
      return render json: { errors: game.errors.full_messages }, status: :unprocessable_entity
    end

    # 再import対処: draft at_batsのみ削除（confirmedは保護）
    game.at_bats.draft.destroy_all

    # パーサー結果からat_batsを作成
    imported_count = create_draft_at_bats(game, parsed)

    render json: {
      game: GameSerializer.new(game).as_json,
      parsed_at_bats: parsed,
      at_bat_count: parsed["innings"]&.sum { |inn| inn["at_bats"]&.length || 0 } || 0,
      imported_count: imported_count
    }, status: :created
  rescue JSON::ParserError => e
    render json: { error: "JSON parse error: #{e.message}" }, status: :unprocessable_entity
  end

  private

  def game_params
    params.require(:game).permit(:competition_id, :home_team_id, :visitor_team_id, :real_date, :stadium_id, :status, :source)
  end

  def create_draft_at_bats(game, parsed)
    seq = 0
    created = 0
    (parsed["innings"] || []).each do |inning_data|
      inning_num = inning_data["inning"].to_i
      half = inning_data["half"].to_s
      (inning_data["at_bats"] || []).each do |ab|
        batter = Player.find_by(name: ab["batter_name"]) || Player.find_by(short_name: ab["batter_name"])
        pitcher = Player.find_by(name: ab["pitcher_name"]) || Player.find_by(short_name: ab["pitcher_name"])
        next if batter.nil? || pitcher.nil?

        seq += 1
        result_code = ab["bat_result"].presence || ab["pitch_result"] || "?"
        game.at_bats.create!(
          batter: batter,
          pitcher: pitcher,
          inning: inning_num,
          half: half,
          seq: seq,
          outs: 0,
          outs_after: 0,
          result_code: result_code,
          play_type: "normal",
          rolls: [],
          runners: [],
          runners_after: [],
          scored: false,
          rbi: 0,
          status: :draft
        )
        created += 1
      end
    end
    created
  end
end
