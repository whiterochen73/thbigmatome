# ノーゲームになった試合を、成績の集計（チーム勝敗・得失点・打撃・投手成績）から外すための判定。
#
# 台帳 D-11（2026-09-12）と再確認（2026-10-26 Operator）: ノーゲームは負傷と登板の疲労計算だけを行い、勝敗・成績は算入しない。
# 成績算入 false は削除ではない。登板記録・打席・原資料は残し、集計側でだけ除外する（疲労・休養の計算は PitcherGameState を
# そのまま読むので、この判定の影響を受けない）。
#
# ノーゲームの試合とは、次のどちらかを満たす試合:
#   1. 試合の日（home_schedule_date / visitor_schedule_date）の試合概要（season_schedules）にノーゲームが立っている。
#      試合概要はチームごとの season に紐づくので、ホスト・ビジターのどちらの側でも見る。
#      同じ日に同じチームの試合概要が複数あり、全部がノーゲームでないなら、どの試合か決められないので対象にしない
#      （PitcherGameResult が ambiguous で判定を保留するのと同じ扱い）
#   2. その試合の登板記録が result_category = "no_game" を持つ（画面の game_result=no_game で保存したもの。試合概要に印が無い場合）
class NoGameGames
  def self.ids
    new.ids
  end

  def ids
    (ids_from_schedules + ids_from_pitcher_states).uniq
  end

  private

  # ノーゲームの印が（その日の全試合概要で）立っているチームと日付の組
  def no_game_keys
    @no_game_keys ||= SeasonSchedule.joins(:season)
                                    .group("seasons.team_id", "season_schedules.date")
                                    .having("bool_and(season_schedules.no_game)")
                                    .pluck("seasons.team_id", "season_schedules.date")
                                    .map { |team_id, date| [ team_id, date.to_date ] }
                                    .to_set
  end

  def ids_from_schedules
    return [] if no_game_keys.empty?

    Game.where.not(home_schedule_date: nil).or(Game.where.not(visitor_schedule_date: nil))
        .pluck(:id, :home_team_id, :home_schedule_date, :visitor_team_id, :visitor_schedule_date)
        .select { |_id, home, home_date, visitor, visitor_date| no_game?(home, home_date) || no_game?(visitor, visitor_date) }
        .map(&:first)
  end

  def ids_from_pitcher_states
    PitcherGameState.where(result_category: "no_game").distinct.pluck(:game_id)
  end

  def no_game?(team_id, schedule_date)
    date = begin
      Date.parse(schedule_date.to_s)
    rescue ArgumentError, TypeError
      nil
    end
    date && no_game_keys.include?([ team_id, date ])
  end
end
