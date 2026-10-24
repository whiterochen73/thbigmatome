# 登板1件の result_category を、サーバ側の情報だけで求める（E1）。
# 疲労P はカード + 試合前のスタミナ補正から求め（PitcherStarterFatigue）、画面の fatigue_p_used には頼らない。
# game_result は呼び出し側が試合概要から決めて渡す（PitcherGameResult）。
class PitcherResultCategory
  # category:       "normal" / "ko" / "long_loss" / "no_game" / nil（判定保留）
  # fatigue_p:      先発の試合前疲労P（補正後）。先発以外・特定できない時は nil
  # pending_reason: category が nil の理由（PitcherStarterFatigue::PENDING_MESSAGES のキー）
  Result = Struct.new(:category, :fatigue_p, :pending_reason, keyword_init: true) do
    def pending? = category.nil?
  end

  def self.call(team_id:, pitcher_id:, schedule_date:, role:, innings_pitched:, no_out_exit:, decision:,
                pitchers_in_game:, prior_outs:, game_result:, result_category_overrides: {})
    fatigue = nil
    if role == "starter" && game_result != "no_game"
      fatigue = PitcherStarterFatigue.call(
        team_id: team_id, pitcher_id: pitcher_id, schedule_date: schedule_date,
        result_category_overrides: result_category_overrides
      )
    end

    category = PitcherGameState.calculate_result_category(
      role: role,
      innings_pitched: innings_pitched,
      game_result: game_result,
      pitchers_in_game: pitchers_in_game,
      fatigue_p: fatigue&.fatigue_p,
      decision: decision,
      no_out_exit: no_out_exit,
      prior_outs: prior_outs
    )

    Result.new(
      category: category,
      fatigue_p: fatigue&.fatigue_p,
      pending_reason: category.nil? ? fatigue&.pending : nil
    )
  end

  def self.pending_message(reason)
    PitcherStarterFatigue::PENDING_MESSAGES[reason] || reason.to_s
  end
end
