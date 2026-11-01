# 登板した投手が、その試合日の試合中に 1軍にいたか（cmd_1784 段3。設計書 §1.3 S7・§4.4 の 6・§7 判断 5）。
#
# 登板の保存は止めない（判断 5: 警告して保存し、試合日ページの「要確認」の帯に出す）。止めると、試合後に抹消した投手の登板や
# 登板日の翌日付けで登録してしまった投手の登板（日付の合わせ違い）という正しい入力も止まる。
#
# 時点は (試合日, in_game)。同じ日の試合前の公示（pre_game）は含み、試合後の公示（post_game）は含まない。
# 読みは RosterState と同じ: 昇降格の記録が無い選手は 2軍、放出済み・まだ登録していない選手は在籍なし。
#
#   first         1軍（問題なし）
#   second        2軍
#   not_on_team   チームに在籍していない（登録前・放出後）
#   no_membership チームの登録（team_memberships の行）が無い
class PitcherRosterStatus
  PHASE = "in_game"
  FIRST = "first"
  NOT_FIRST = %w[second not_on_team no_membership].freeze
  LABELS = {
    "second" => "2軍",
    "not_on_team" => "チームに在籍していない",
    "no_membership" => "チームの登録が無い"
  }.freeze

  # { pitcher_id => 状態 }。pitcher_ids が空なら問い合わせない
  def self.for(team:, date:, pitcher_ids:)
    ids = pitcher_ids.compact
    return {} if ids.empty?

    memberships = team.all_team_memberships.where(player_id: ids).preload(:season_rosters, :team_membership_changes).to_a
    state = RosterState.new(team, memberships: memberships)
    entries = state.at(date, PHASE)
    by_player = memberships.index_by(&:player_id)
    ids.index_with do |pitcher_id|
      tm = by_player[pitcher_id]
      if tm.nil? then "no_membership"
      else
        entry = entries.fetch(tm.id)
        if !entry.on_team then "not_on_team"
        elsif entry.squad == "first" then FIRST
        else "second"
        end
      end
    end
  end

  def self.off_roster?(status)
    NOT_FIRST.include?(status)
  end

  # 登板の保存時の警告文。pitcher_name は表示用（無ければ ID）
  def self.warning_message(pitcher_name:, date:, status:)
    "#{pitcher_name}: #{date} の試合中は1軍にいません（#{LABELS.fetch(status)}）。登板は保存しました。昇降格の日付か登板の入力を確かめてください"
  end
end
