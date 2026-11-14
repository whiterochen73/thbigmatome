# 時限選手（カードの特徴欄に日付の範囲。PlayerCard#availability_period）の起用の記録が、期間外の日付でないかを調べる（cmd_1896）。
#
# 起用の記録（登板・試合の先発メンバー）は止めずに警告にして保存する。Dugout は他チームの記録も書ける前提で、
# 既存の 1軍でない投手の登板（PitcherRosterStatus）も同じ扱いのため、それに揃えた。
# 登録（昇降格）の側は RosterConstraintChecker の kind time_limited_player が止める。
#
# カードは、その日の（試合中の）契約・カードを RosterState から読む。年はシーズン初日（日程の最初の日）で解決する。
class TimeLimitedPlayerCheck
  PHASE = "in_game"

  # 期間外の選手ごとの警告文の配列。player_ids が空・チームにシーズンが無ければ空
  def self.warnings(team:, date:, player_ids:)
    ids = player_ids.compact.uniq
    return [] if ids.empty? || team.nil?

    memberships = team.all_team_memberships.where(player_id: ids)
                      .preload(:season_rosters, :team_membership_changes, player: :cost_players, player_card: [ :card_set, :player_card_defenses ]).to_a
    return [] if memberships.empty?

    state = RosterState.new(team, memberships: memberships)
    entries = state.at(date, PHASE)
    anchor = team.season&.season_schedules&.minimum(:date)
    memberships.filter_map do |tm|
      entry = entries.fetch(tm.id)
      next unless entry.on_team

      card = state.view(tm, entry).player_card
      next if card.nil? || card.available_on?(date, anchor: anchor)

      I18n.t("activerecord.errors.models.player_card.time_limited.out_of_period_record",
             name: tm.player.name, period: card.availability_period_label, date: date.to_s)
    end
  end
end
