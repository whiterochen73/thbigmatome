class Api::V1::GameRecordsController < Api::V1::BaseController
  before_action :set_game_record, only: [ :show, :confirm ]

  # GET /api/v1/game_records
  def index
    game_records = GameRecord.all.order(id: :desc)
    game_records = game_records.where(team_id: params[:team_id]) if params[:team_id].present?
    game_records = game_records.where(status: params[:status]) if params[:status].present?
    if params[:game_date_from].present? && params[:game_date_to].present?
      game_records = game_records.where(game_date: params[:game_date_from]..params[:game_date_to])
    end

    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i.clamp(1, 100)
    total = game_records.count
    game_records = game_records.offset((page - 1) * per_page).limit(per_page)

    render json: {
      game_records: game_records.map { |gr| serialize_game_record(gr) },
      pagination: {
        page: page,
        per_page: per_page,
        total: total,
        total_pages: (total.to_f / per_page).ceil
      }
    }
  end

  # GET /api/v1/game_records/:id
  def show
    render json: serialize_game_record(@game_record, include_at_bats: true)
  end

  # POST /api/v1/game_records
  def create
    game_record = GameRecord.new(game_record_params)
    game_record.status = "draft"

    GameRecord.transaction do
      game_record.save!

      if params[:at_bat_records].present?
        params[:at_bat_records].each do |ab_params|
          attrs = at_bat_record_create_params(ab_params).to_h
          raw_disc = ab_params[:discrepancies] || ab_params["discrepancies"]
          attrs[:discrepancies] = normalize_discrepancies(raw_disc) if raw_disc.present?
          attrs[:source_events] = build_source_events(ab_params)
          game_record.at_bat_records.create!(attrs)
        end
      end
    end

    render json: serialize_game_record(game_record, include_at_bats: true), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordNotSaved => e
    render json: { errors: [ e.message ] }, status: :unprocessable_content
  end

  # POST /api/v1/game_records/:id/confirm
  def confirm
    unless @game_record.draft?
      return render json: { error: "Game record is not in draft status" }, status: :unprocessable_content
    end

    @game_record.update!(status: "confirmed", confirmed_at: Time.current)
    render json: serialize_game_record(@game_record, include_at_bats: false)
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
  end

  private

  def set_game_record
    @game_record = GameRecord.includes(:at_bat_records).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Game record not found" }, status: :not_found
  end

  def game_record_params
    params.permit(
      :team_id, :opponent_team_name, :game_date, :played_at, :stadium,
      :score_home, :score_away, :result, :source_log, :parser_version, :parsed_at
    )
  end

  def at_bat_record_create_params(ab_params)
    ab_params.permit(
      :inning, :half, :ab_num, :pitcher_name, :pitcher_id, :batter_name, :batter_id,
      :pitch_roll, :pitch_result, :bat_roll, :bat_result, :result_code, :strategy,
      :outs_before, :outs_after, :runs_scored, :play_description,
      runners_before: {}, runners_after: {}, extra_data: {}, source_events: []
    )
  end

  # パーサー出力の各フィールドからsource_eventsを構築する
  # 宣言(declaration) / ダイス(dice) / 自動計算(auto) の3分類
  def build_source_events(ab_params)
    raw = ab_params.respond_to?(:to_unsafe_h) ? ab_params.to_unsafe_h : ab_params.to_h
    raw = raw.with_indifferent_access

    events = []
    seq = 0

    # 1. 宣言: eventsフィールド（投手交代/代打/代走等）
    Array(raw[:events]).each do |ev|
      type = (ev[:type] || ev["type"] || ev[:event_type] || ev["event_type"]).to_s
      next if type.blank?
      seq += 1
      entry = { seq: seq, type: "declaration", subtype: type }
      entry[:speaker] = ev[:speaker] if ev[:speaker].present?
      entry[:text] = ev[:text] if ev[:text].present?
      events << entry
    end

    # 2. 宣言: strategy（エンドラン/バント/故意四球/盗塁）
    strategy = raw[:strategy].to_s
    if %w[endrun bunt bunt_fc intentional_walk steal].include?(strategy)
      seq += 1
      events << { seq: seq, type: "declaration", subtype: strategy }
    end

    # 3. 宣言: 内野/外野前進守備
    infield = raw[:infield_forward].present? && raw[:infield_forward] != false && raw[:infield_forward] != "false"
    outfield = raw[:outfield_forward].present? && raw[:outfield_forward] != false && raw[:outfield_forward] != "false"
    if infield && outfield
      seq += 1
      events << { seq: seq, type: "declaration", subtype: "infield_outfield_forward" }
    elsif infield
      seq += 1
      events << { seq: seq, type: "declaration", subtype: "infield_forward" }
    elsif outfield
      seq += 1
      events << { seq: seq, type: "declaration", subtype: "outfield_forward" }
    end

    # 4. ダイス: 盗塁（st/ed判定）— 打席前に発生
    Array(raw[:steal_attempts]).each do |steal|
      base = steal[:base]
      st_dice = steal[:st_dice]
      if st_dice
        seq += 1
        events << { seq: seq, type: "dice", subtype: "steal_st",
                    roll: st_dice.to_i, base: base, result: steal[:st_result].to_s }
      end
      ed_dice = steal[:ed_dice]
      if ed_dice
        seq += 1
        events << { seq: seq, type: "dice", subtype: "steal_ed",
                    roll: ed_dice.to_i, base: base, result: steal[:ed_result].to_s }
      end
    end

    # 5. ダイス: 投球
    pitch_roll = raw[:pitch_roll]
    if pitch_roll.present?
      seq += 1
      events << { seq: seq, type: "dice", subtype: "pitch",
                  roll: pitch_roll.to_i, result: raw[:pitch_result].to_s }
    end

    # 6. ダイス: 打撃
    bat_roll = raw[:bat_roll]
    if bat_roll.present?
      seq += 1
      events << { seq: seq, type: "dice", subtype: "bat",
                  roll: bat_roll.to_i, result: raw[:bat_result].to_s }
    end

    # 7. ダイス: extra_rolls（レンジチェック/エラーチェック/UP表/肩チェック等）
    Array(raw[:extra_rolls]).each do |roll|
      roll_val = roll[:roll]
      result = roll[:result].to_s
      event_type = roll[:event_type].to_s
      dice_list = roll[:dice_list]

      subtype = case event_type
      when "range_check" then "range_check"
      when "error_check" then "error_check"
      when "up_table"    then "up_table"
      when "shoulder_check" then "shoulder_check"
      when "bunt"        then "bunt_roll"
      else "extra"
      end

      entry = { seq: (seq += 1), type: "dice", subtype: subtype,
                roll: roll_val, result: result }
      entry[:dice_list] = dice_list if dice_list.present?
      entry[:event_type] = event_type if subtype == "extra" && event_type.present?
      events << entry.compact
    end

    # 8. 自動計算: 走者進塁
    runners_before = Array(raw[:runners_before]).map(&:to_i).sort
    runners_after  = Array(raw[:runners_after]).map(&:to_i).sort
    if runners_before != runners_after
      seq += 1
      events << { seq: seq, type: "auto", subtype: "runner_advance",
                  runners_before: runners_before, runners_after: runners_after }
    end

    # 9. 自動計算: 得点
    runs_scored = raw[:runs_scored].to_i
    if runs_scored > 0
      seq += 1
      events << { seq: seq, type: "auto", subtype: "scoring", runs: runs_scored }
    end

    # 10. 自動計算: アウトカウント変化
    outs_before = raw[:outs_before]
    outs_after  = raw[:outs_after]
    if outs_before.present? && outs_after.present? && outs_before.to_i != outs_after.to_i
      seq += 1
      events << { seq: seq, type: "auto", subtype: "out_recorded",
                  outs_before: outs_before.to_i, outs_after: outs_after.to_i }
    end

    events
  end

  # パーサー出力形式 { field, text, gsm } → DB格納形式 { field, text_value, gsm_value, cause, resolution } に変換
  def normalize_discrepancies(raw_discrepancies)
    Array(raw_discrepancies).map do |d|
      {
        "field" => d[:field] || d["field"],
        "text_value" => d[:text] || d["text"],
        "gsm_value" => d[:gsm] || d["gsm"],
        "cause" => d[:cause] || d["cause"] || "unknown",
        "resolution" => d[:resolution] || d["resolution"],
        "note" => d[:note] || d["note"]
      }.compact
    end
  end

  def serialize_game_record(game_record, include_at_bats: false)
    data = {
      id: game_record.id,
      team_id: game_record.team_id,
      opponent_team_name: game_record.opponent_team_name,
      game_date: game_record.game_date,
      played_at: game_record.played_at,
      stadium: game_record.stadium,
      score_home: game_record.score_home,
      score_away: game_record.score_away,
      result: game_record.result,
      status: game_record.status,
      parser_version: game_record.parser_version,
      parsed_at: game_record.parsed_at,
      confirmed_at: game_record.confirmed_at,
      created_at: game_record.created_at,
      updated_at: game_record.updated_at
    }

    if include_at_bats
      data[:at_bat_records] = game_record.at_bat_records.order(:ab_num).map do |ab|
        serialize_at_bat_record(ab)
      end
    end

    data
  end

  def serialize_at_bat_record(ab)
    {
      id: ab.id,
      game_record_id: ab.game_record_id,
      inning: ab.inning,
      half: ab.half,
      ab_num: ab.ab_num,
      pitcher_name: ab.pitcher_name,
      pitcher_id: ab.pitcher_id,
      batter_name: ab.batter_name,
      batter_id: ab.batter_id,
      pitch_roll: ab.pitch_roll,
      pitch_result: ab.pitch_result,
      bat_roll: ab.bat_roll,
      bat_result: ab.bat_result,
      result_code: ab.result_code,
      strategy: ab.strategy,
      runners_before: ab.runners_before,
      runners_after: ab.runners_after,
      outs_before: ab.outs_before,
      outs_after: ab.outs_after,
      runs_scored: ab.runs_scored,
      is_modified: ab.is_modified,
      modified_fields: ab.modified_fields,
      play_description: ab.play_description,
      extra_data: ab.extra_data,
      discrepancies: ab.discrepancies,
      source_events: ab.source_events,
      created_at: ab.created_at,
      updated_at: ab.updated_at
    }
  end
end
