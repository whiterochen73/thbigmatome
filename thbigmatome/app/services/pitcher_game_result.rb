# その試合の勝敗を、試合概要（season_schedules.score / opponent_score。自チーム視点）から求める。
# 画面が送る game_result には頼らない（Operator 裁定 2026-10-25）。
# 得点が未入力・同点は負けではない。
class PitcherGameResult
  # found:  試合概要（season_schedule）が一意に見つかったか
  # scored: 両チームの得点が入力済みか
  # result: "win" / "lose" / "draw"（未入力は "draw" = 負けではない扱い）。found が false なら nil
  # note:   found が false の理由（:not_found / :ambiguous）
  Outcome = Struct.new(:found, :scored, :result, :note, keyword_init: true)

  def self.for(team_id:, schedule_date:)
    date = begin
      Date.parse(schedule_date.to_s)
    rescue ArgumentError, TypeError
      nil
    end
    return Outcome.new(found: false, scored: false, result: nil, note: :not_found) if date.nil?

    schedules = SeasonSchedule.joins(:season).where(seasons: { team_id: team_id }, date: date).to_a
    return Outcome.new(found: false, scored: false, result: nil, note: :not_found) if schedules.empty?
    return Outcome.new(found: false, scored: false, result: nil, note: :ambiguous) if schedules.size > 1

    schedule = schedules.first
    return Outcome.new(found: true, scored: false, result: "draw") if schedule.score.nil? || schedule.opponent_score.nil?

    result = if schedule.score > schedule.opponent_score then "win"
    elsif schedule.score < schedule.opponent_score then "lose"
    else "draw"
    end
    Outcome.new(found: true, scored: true, result: result)
  end
end
