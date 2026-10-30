module CooldownCalculable
  extend ActiveSupport::Concern

  private

  # Rule 3: Cooldown calculation with same-day exemption info
  # 昇降格の変更記録から導く（RosterState。直前と同じ区分への記録は畳んでから降格日を数える）。
  # Returns { cooldown_until: Date|nil, same_day_exempt: boolean, demotion_date: Date|nil }
  def calculate_cooldown_info(team_membership, current_date, phase = RosterState::DEFAULT_PHASE)
    state = roster_state_for_team(team_membership.team)
    entry = state.entry(team_membership.id, current_date, phase)
    return RosterState::NO_COOLDOWN.dup unless entry

    { cooldown_until: entry.cooldown_until, same_day_exempt: entry.same_day_exempt, demotion_date: entry.demotion_date }
  end

  # チームごとの RosterState をリクエストの間だけ使い回す（記録の読み込みを 1 回にする）。書き込みの後は使わないこと
  def roster_state_for_team(team)
    @roster_states ||= {}
    @roster_states[team.id] ||= RosterState.new(team)
  end
end
