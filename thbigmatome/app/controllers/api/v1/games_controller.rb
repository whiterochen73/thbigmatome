require "open3"
require "tempfile"

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

  def parse_log
    log_text = params[:log]
    return render json: { error: "log parameter required" }, status: :bad_request if log_text.blank?

    python_path = ENV.fetch("THBIG_IRC_PARSER_PYTHON", "/home/morinaga/projects/thbig-irc-parser/.venv/bin/python")
    stdout, stderr, status = Tempfile.create([ "irc_log", ".txt" ]) do |tmp|
      tmp.write(log_text)
      tmp.flush
      Open3.capture3(python_path, "-m", "thbig_irc_parser.parse_game_full", tmp.path)
    end

    unless status.success?
      error_message = if stderr.include?("ModuleNotFoundError") || stderr.include?("No module named")
        "パーサーが見つかりません。thbig_irc_parser のセットアップを確認してください。"
      else
        "Parser error: #{stderr.truncate(200)}"
      end
      return render json: { error: error_message }, status: :unprocessable_content
    end

    result = JSON.parse(stdout)
    at_bats_data = result["at_bats"]
    pregame_info = result["pregame_info"]

    all_at_bats = (at_bats_data["innings"] || []).flat_map do |inn|
      (inn["at_bats"] || []).map do |ab|
        {
          inning: inn["inning"],
          top_bottom: inn["half"],
          order: ab["ab_num"],
          batter: ab["batter_name"],
          pitcher: ab["pitcher_name"],
          result_code: ab["bat_result"].presence || ab["pitch_result"] || "?",
          runners_before: ab["runners_before"] || [],
          outs_after: ab["outs_after"],
          runners_after: ab["runners_after"] || [],
          score: ab["score"],
          runs_scored: ab["runs_scored"] || 0,
          wild_pitch: ab["wild_pitch"] || false,
          wild_pitch_type: ab["wild_pitch_type"],
          events: ab["events"] || []
        }
      end
    end

    render json: {
      pregame_info: pregame_info,
      parsed_at_bats: {
        at_bats: all_at_bats,
        innings: (at_bats_data["innings"] || []).length
      },
      at_bat_count: all_at_bats.length,
      raw_at_bats: at_bats_data
    }
  rescue JSON::ParserError => e
    render json: { error: "JSON parse error: #{e.message}" }, status: :unprocessable_content
  end

  def import_log
    log_text = params[:log]
    return render json: { error: "log parameter required" }, status: :bad_request if log_text.blank?

    # parse_logのキャッシュがあれば再解析をスキップ（二重読み込み解消）
    parsed = if params[:raw_at_bats].present?
      JSON.parse(params[:raw_at_bats])
    else
      # パーサー呼び出し
      python_path = ENV.fetch("THBIG_IRC_PARSER_PYTHON", "/home/morinaga/projects/thbig-irc-parser/.venv/bin/python")
      stdout, stderr, status = Tempfile.create([ "irc_log", ".txt" ]) do |tmp|
        tmp.write(log_text)
        tmp.flush
        line_count = log_text.lines.count
        Open3.capture3(python_path, "-m", "thbig_irc_parser.log_parser", tmp.path, "1", line_count.to_s)
      end

      unless status.success?
        error_message = if stderr.include?("ModuleNotFoundError") || stderr.include?("No module named")
          "パーサーが見つかりません。thbig_irc_parser のセットアップを確認してください。"
        else
          "Parser error: #{stderr.truncate(200)}"
        end
        return render json: { error: error_message }, status: :unprocessable_content
      end

      JSON.parse(stdout)
    end

    # draft Gameを作成（raw_logを保存）
    game_params_for_import = {
      competition_id: params[:competition_id],
      home_team_id: params[:home_team_id],
      visitor_team_id: params[:visitor_team_id],
      real_date: params[:real_date],
      stadium_id: params[:stadium_id],
      status: "draft",
      source: "log_import",
      raw_log: log_text
    }

    game = Game.new(game_params_for_import)
    unless game.valid?
      return render json: { errors: game.errors.full_messages }, status: :unprocessable_content
    end

    game_record = nil
    imported_count = 0

    ActiveRecord::Base.transaction do
      game.save!

      # 再import対処: draft at_batsのみ削除（confirmedは保護）
      game.at_bats.draft.destroy_all

      # パーサー結果からat_batsを作成
      imported_count = create_draft_at_bats(game, parsed)

      # GameRecord作成（game_id紐付け）
      game_record = GameRecord.create!(
        game_id: game.id,
        team_id: params[:home_team_id],
        game_date: params[:real_date],
        source_log: log_text,
        parsed_at: Time.current,
        status: "draft"
      )

      # AtBatRecords作成
      create_import_at_bat_records(game_record, parsed)
    end

    all_at_bats = (parsed["innings"] || []).flat_map do |inn|
      (inn["at_bats"] || []).map do |ab|
        {
          inning: inn["inning"],
          top_bottom: inn["half"],
          order: ab["ab_num"],
          batter: ab["batter_name"],
          pitcher: ab["pitcher_name"],
          result_code: ab["bat_result"].presence || ab["pitch_result"] || "?",
          runners_before: ab["runners_before"] || [],
          outs_after: ab["outs_after"],
          runners_after: ab["runners_after"] || [],
          score: ab["score"],
          runs_scored: ab["runs_scored"] || 0,
          wild_pitch: ab["wild_pitch"] || false,
          wild_pitch_type: ab["wild_pitch_type"],
          events: ab["events"] || []
        }
      end
    end
    innings_count = (parsed["innings"] || []).length
    render json: {
      game: GameSerializer.new(game).as_json,
      game_record_id: game_record.id,
      parsed_at_bats: {
        at_bats: all_at_bats,
        innings: innings_count
      },
      at_bat_count: all_at_bats.length,
      imported_count: imported_count
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
  rescue JSON::ParserError => e
    render json: { error: "JSON parse error: #{e.message}" }, status: :unprocessable_content
  end

  private

  def game_params
    params.require(:game).permit(:competition_id, :home_team_id, :visitor_team_id, :real_date, :stadium_id, :status, :source)
  end

  def create_import_at_bat_records(game_record, parsed)
    ab_num = 0
    (parsed["innings"] || []).each do |inning_data|
      inning_num = inning_data["inning"].to_i
      half = inning_data["half"].to_s
      (inning_data["at_bats"] || []).each do |ab|
        ab_num += 1
        ab_hash = ab.with_indifferent_access
        attrs = {
          inning: inning_num,
          half: half,
          ab_num: ab_num,
          batter_name: ab_hash[:batter_name],
          pitcher_name: ab_hash[:pitcher_name],
          pitch_roll: ab_hash[:pitch_roll],
          pitch_result: ab_hash[:pitch_result],
          bat_roll: ab_hash[:bat_roll],
          bat_result: ab_hash[:bat_result],
          result_code: ab_hash[:bat_result].presence || ab_hash[:pitch_result] || "?",
          outs_before: ab_hash[:outs_before],
          outs_after: ab_hash[:outs_after],
          runs_scored: ab_hash[:runs_scored] || 0,
          runners_before: ab_hash[:runners_before] || [],
          runners_after: ab_hash[:runners_after] || []
        }
        attrs[:source_events] = AtBatRecordBuilder.build_source_events(ab_hash)
        raw_disc = ab_hash[:discrepancies]
        attrs[:discrepancies] = AtBatRecordBuilder.normalize_discrepancies(raw_disc) if raw_disc.present?
        game_record.at_bat_records.create!(attrs)
      end
    end
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
