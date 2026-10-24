class Api::V1::PitcherAppearancesController < Api::V1::BaseController
  # GET /api/v1/pitcher_appearances?team_id=X&schedule_date=YYYY-MM-DD
  def index
    team_id = params[:team_id]
    schedule_date = params[:schedule_date]

    unless team_id.present? && schedule_date.present?
      render json: [], status: :ok
      return
    end

    appearances = PitcherGameState
      .where(team_id: team_id, schedule_date: schedule_date)
      .order(:appearance_order)

    render json: appearances.map { |a|
      {
        id: a.id,
        pitcher_id: a.pitcher_id,
        role: a.role,
        innings_pitched: a.innings_pitched&.to_f,
        earned_runs: a.earned_runs,
        fatigue_p_used: a.fatigue_p_used,
        decision: a.decision,
        is_opener: a.is_opener,
        no_out_exit: a.no_out_exit,
        consecutive_short_rest_count: a.consecutive_short_rest_count,
        pre_injury_days_excluded: a.pre_injury_days_excluded,
        result_category: a.result_category,
        injury_check: a.injury_check,
        schedule_date: a.schedule_date,
        team_id: a.team_id,
        game_id: a.game_id,
        competition_id: a.competition_id,
        appearance_order: a.appearance_order
      }
    }
  end

  # POST /api/v1/pitcher_appearances/bulk_save
  def bulk_save
    bulk = params[:pitcher_appearances_bulk]
    appearances_list = bulk[:appearances] || []
    team_id = bulk[:team_id]
    # 勝敗は試合概要の得点から決める。画面が送る game_result は、試合概要が無い時の代替と no_game の指定にだけ使う
    game_result, schedule_ambiguous = resolve_game_result(team_id, bulk[:schedule_date], bulk[:game_result])

    game = find_or_create_game_for_bulk
    return if game.nil?

    error_response = nil
    all_results = []
    all_warnings = []
    pitchers_count = appearances_list.count { |a| a[:pitcher_id].present? }
    running_outs = 0

    ActiveRecord::Base.transaction do
      # リクエストに含まれない既存レコードを削除（UIで行を消した投手のDBレコードを掃除）
      submitted_pitcher_ids = appearances_list.map { |a| a[:pitcher_id] }.compact
      PitcherGameState.where(game_id: game.id, team_id: team_id)
                      .where.not(pitcher_id: submitted_pitcher_ids)
                      .destroy_all

      appearances_list.each_with_index do |ap, idx|
        next if ap[:pitcher_id].blank?

        hash = bulk_appearance_params(ap).to_h.symbolize_keys
        hash[:game_id] = game.id
        hash[:team_id] = team_id
        hash[:schedule_date] = bulk[:schedule_date]
        hash[:competition_id] ||= game.competition_id
        hash[:appearance_order] = idx

        prior_outs = running_outs
        running_outs += PitcherInnings.outs_from_innings(hash[:innings_pitched])

        if hash[:result_category].blank?
          assign_result_category(
            hash,
            team_id: team_id, schedule_date: bulk[:schedule_date], game_result: game_result,
            schedule_ambiguous: schedule_ambiguous, pitchers_in_game: pitchers_count,
            prior_outs: prior_outs, warnings: all_warnings
          )
        end

        state = PitcherGameState.find_or_initialize_by(game_id: game.id, pitcher_id: hash[:pitcher_id])
        state.assign_attributes(hash)

        unless state.save
          error_response = { errors: state.errors.full_messages, pitcher_id: ap[:pitcher_id].to_i }
          raise ActiveRecord::Rollback
        end

        all_results << state
      end

      all_results.each do |state|
        all_warnings.concat(validate_decision(state, game_result))
      end
    end

    if error_response
      render json: error_response, status: :unprocessable_entity
    else
      render json: { pitcher_appearances: all_results.map(&:as_json), warnings: all_warnings }, status: :ok
    end
  end

  # POST /api/v1/pitcher_appearances
  def create
    game = find_or_create_game
    return if game.nil?

    appearance_params_hash = pitcher_appearance_params.to_h
    appearance_params_hash[:game_id] = game.id
    # competition_idがparams未指定の場合、gameから補完
    appearance_params_hash[:competition_id] ||= game.competition_id

    # result_category の自動計算（勝敗は試合概要の得点から決める）
    game_result, schedule_ambiguous = resolve_game_result(
      appearance_params_hash[:team_id], appearance_params_hash[:schedule_date],
      params.dig(:pitcher_appearance, :game_result)
    )
    create_warnings = []
    if appearance_params_hash[:result_category].blank?
      game_appearances = PitcherGameState.where(game_id: game.id, team_id: appearance_params_hash[:team_id])
      pitchers_count = game_appearances.count + 1  # 自分を含む
      # appearance_order は単発登録では受け取らないため、前の投手のアウト数は 0（先発として最初に投げる想定）
      assign_result_category(
        appearance_params_hash,
        team_id: appearance_params_hash[:team_id], schedule_date: appearance_params_hash[:schedule_date],
        game_result: game_result, schedule_ambiguous: schedule_ambiguous,
        pitchers_in_game: pitchers_count, prior_outs: 0, warnings: create_warnings
      )
    end

    state = PitcherGameState.new(appearance_params_hash)
    warnings = create_warnings + validate_decision(state, game_result)

    if state.save
      render json: { pitcher_appearance: state.as_json, warnings: warnings }, status: :created
    else
      render json: { errors: state.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  # 勝敗を試合概要（season_schedules の score / opponent_score）から決める。
  # 戻り値: [game_result, schedule_ambiguous]
  # - 画面の指定が no_game ならそのまま（得点では表せないため）
  # - 試合概要が一意に見つかれば、画面の値は無視して得点から決める（未入力・同点は draw = 負けではない）
  # - 試合概要が見つからない時だけ、画面の値を代替に使う（無ければ draw）
  # - 試合概要が複数あって決められない時は game_result を nil にして判定保留にする
  def resolve_game_result(team_id, schedule_date, hint)
    return [ "no_game", false ] if hint.to_s == "no_game"

    outcome = PitcherGameResult.for(team_id: team_id, schedule_date: schedule_date)
    return [ outcome.result, false ] if outcome.found
    return [ nil, true ] if outcome.note == :ambiguous

    [ hint.presence || "draw", false ]
  end

  # attrs に result_category と（先発の）fatigue_p_used を書き込む。判定保留は result_category = nil + 警告。
  def assign_result_category(attrs, team_id:, schedule_date:, game_result:, schedule_ambiguous:, pitchers_in_game:, prior_outs:, warnings:)
    if schedule_ambiguous
      attrs[:result_category] = nil
      attrs[:fatigue_p_used] = nil if attrs[:role] == "starter"
      warnings << "投手ID #{attrs[:pitcher_id]}: 判定保留 - 同じ日付の試合概要が複数あり、勝敗を決められない（result_category 未設定）"
      return
    end

    result = PitcherResultCategory.call(
      team_id: team_id, pitcher_id: attrs[:pitcher_id], schedule_date: schedule_date,
      role: attrs[:role], innings_pitched: attrs[:innings_pitched].to_f, no_out_exit: attrs[:no_out_exit],
      decision: attrs[:decision], pitchers_in_game: pitchers_in_game, prior_outs: prior_outs,
      game_result: game_result
    )
    attrs[:result_category] = result.category
    # 先発の fatigue_p_used はサーバが求めた値（試合前のスタミナ補正後）で上書きする。特定できなければ nil
    attrs[:fatigue_p_used] = result.fatigue_p if attrs[:role] == "starter" && game_result != "no_game"
    return unless result.pending?

    warnings << "投手ID #{attrs[:pitcher_id]}: 判定保留 - #{PitcherResultCategory.pending_message(result.pending_reason)}（result_category 未設定）"
  end

  def find_or_create_game_for_bulk
    bulk = params[:pitcher_appearances_bulk]
    team_id = bulk[:team_id]
    competition_id = bulk[:competition_id]
    schedule_date = bulk[:schedule_date]
    game_id = bulk[:game_id]

    if game_id.present?
      game = Game.find_by(id: game_id)
      unless game
        render json: { errors: [ "Game not found" ] }, status: :not_found
        return nil
      end
      return game
    end

    unless team_id.present? && schedule_date.present?
      render json: { errors: [ "game_id or (team_id, schedule_date) is required" ] }, status: :unprocessable_entity
      return nil
    end

    if competition_id.blank?
      year = Date.parse(schedule_date.to_s).year
      competition_entry = CompetitionEntry.joins(:competition)
                                          .where(team_id: team_id)
                                          .where(competitions: { year: year, competition_type: "league_pennant" })
                                          .first
      competition_id = competition_entry&.competition_id
    end

    game = if competition_id.present?
      Game.where(competition_id: competition_id)
          .where("home_team_id = ? OR visitor_team_id = ?", team_id, team_id)
          .where("home_schedule_date = ? OR visitor_schedule_date = ?", schedule_date, schedule_date)
          .first
    else
      Game.where("home_team_id = ? OR visitor_team_id = ?", team_id, team_id)
          .where("home_schedule_date = ? OR visitor_schedule_date = ?", schedule_date, schedule_date)
          .first
    end

    game ||= Game.create!(
      competition_id: competition_id,
      home_team_id: team_id,
      visitor_team_id: team_id,
      home_schedule_date: schedule_date,
      visitor_schedule_date: schedule_date,
      source: "summary",
      status: "draft"
    )

    game
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    nil
  end

  def find_or_create_game
    team_id = params.dig(:pitcher_appearance, :team_id)
    competition_id = params.dig(:pitcher_appearance, :competition_id)
    schedule_date = params.dig(:pitcher_appearance, :schedule_date)
    game_id = params.dig(:pitcher_appearance, :game_id)

    if game_id.present?
      game = Game.find_by(id: game_id)
      unless game
        render json: { errors: [ "Game not found" ] }, status: :not_found
        return nil
      end
      return game
    end

    unless team_id.present? && schedule_date.present?
      render json: { errors: [ "game_id or (team_id, schedule_date) is required" ] }, status: :unprocessable_entity
      return nil
    end

    # competition_idが未指定の場合、team_id + yearからleague_pennantを自動検索
    if competition_id.blank?
      year = Date.parse(schedule_date.to_s).year
      competition_entry = CompetitionEntry.joins(:competition)
                                          .where(team_id: team_id)
                                          .where(competitions: { year: year, competition_type: "league_pennant" })
                                          .first
      competition_id = competition_entry&.competition_id
    end

    # home / visitor 両側を探す
    game = if competition_id.present?
      Game.where(competition_id: competition_id)
          .where("home_team_id = ? OR visitor_team_id = ?", team_id, team_id)
          .where("home_schedule_date = ? OR visitor_schedule_date = ?", schedule_date, schedule_date)
          .first
    else
      Game.where("home_team_id = ? OR visitor_team_id = ?", team_id, team_id)
          .where("home_schedule_date = ? OR visitor_schedule_date = ?", schedule_date, schedule_date)
          .first
    end

    game ||= Game.create!(
      competition_id: competition_id,
      home_team_id: team_id,
      visitor_team_id: team_id,
      home_schedule_date: schedule_date,
      visitor_schedule_date: schedule_date,
      source: "summary",
      status: "draft"
    )

    game
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    nil
  end

  def validate_decision(state, game_result)
    warnings = []
    return warnings unless state.decision.present?

    game_states = PitcherGameState.where(game_id: state.game_id, team_id: state.team_id)

    case state.decision
    when "W"
      warnings << "W（勝利投手）は勝ち試合のみです" if game_result != "win"
      warnings << "W（勝利投手）は試合に1人のみです" if game_states.where(decision: "W").exists?
    when "L"
      warnings << "L（敗戦投手）は負け試合のみです" if game_result != "lose"
      warnings << "L（敗戦投手）は試合に1人のみです" if game_states.where(decision: "L").exists?
    when "S"
      warnings << "S（セーブ）は先発以外（リリーフ/オープナー）のみです" if state.role == "starter"
      warnings << "S（セーブ）は試合に1人のみです" if game_states.where(decision: "S").exists?
      warnings << "S（セーブ）は勝ち試合のみです" if game_result != "win"
    when "H"
      warnings << "H（ホールド）は先発以外（リリーフ/オープナー）のみです" if state.role == "starter"
      # H（ホールド）は複数可・最後の投手でないことはFE側で制御
    end

    warnings
  end

  def bulk_appearance_params(ap)
    ap.permit(
      :pitcher_id,
      :role,
      :innings_pitched,
      :earned_runs,
      :fatigue_p_used,
      :decision,
      :result_category,
      :injury_check,
      :is_opener,
      :consecutive_short_rest_count,
      :pre_injury_days_excluded,
      :cumulative_innings,
      :appearance_order,
      :no_out_exit
    )
  end

  def pitcher_appearance_params
    params.require(:pitcher_appearance).permit(
      :pitcher_id,
      :team_id,
      :competition_id,
      :role,
      :innings_pitched,
      :earned_runs,
      :fatigue_p_used,
      :decision,
      :result_category,
      :injury_check,
      :schedule_date,
      :is_opener,
      :consecutive_short_rest_count,
      :pre_injury_days_excluded,
      :cumulative_innings,
      :no_out_exit
    )
  end
end
