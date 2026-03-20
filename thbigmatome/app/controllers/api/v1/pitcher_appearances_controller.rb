class Api::V1::PitcherAppearancesController < Api::V1::BaseController
  # POST /api/v1/pitcher_appearances
  def create
    game = find_or_create_game
    return if game.nil?

    appearance_params_hash = pitcher_appearance_params.to_h
    appearance_params_hash[:game_id] = game.id

    # result_category の自動計算
    if appearance_params_hash[:result_category].blank?
      game_appearances = PitcherGameState.where(game_id: game.id, team_id: appearance_params_hash[:team_id])
      pitchers_count = game_appearances.count + 1  # 自分を含む
      role = appearance_params_hash[:role]
      innings = appearance_params_hash[:innings_pitched].to_f

      game_result = params.dig(:pitcher_appearance, :game_result)
      appearance_params_hash[:result_category] = PitcherGameState.calculate_result_category(
        role: role,
        innings_pitched: innings,
        game_result: game_result,
        pitchers_in_game: pitchers_count,
        fatigue_p: appearance_params_hash[:fatigue_p_used].to_i,
        decision: appearance_params_hash[:decision]
      )
    end

    state = PitcherGameState.new(appearance_params_hash)
    warnings = validate_decision(state, game_result)

    if state.save
      render json: { pitcher_appearance: state.as_json, warnings: warnings }, status: :created
    else
      render json: { errors: state.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

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

    unless team_id.present? && competition_id.present? && schedule_date.present?
      render json: { errors: [ "game_id or (team_id, competition_id, schedule_date) is required" ] }, status: :unprocessable_entity
      return nil
    end

    # home / visitor 両側を探す
    game = Game.where(competition_id: competition_id)
               .where("home_team_id = ? OR visitor_team_id = ?", team_id, team_id)
               .where("home_schedule_date = ? OR visitor_schedule_date = ?", schedule_date, schedule_date)
               .first

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
      :cumulative_innings
    )
  end
end
