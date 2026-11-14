require "csv"

# 在籍中の所属のカードを、現行外の PM 系セット（PM2026）のカードから現行の PM 系セット（PM2027）の同じカードへ付け替える（cmd_1898 / subtask_1898b）。
#
# 当て先は「同じ Player・同じ種別（card_type）・同じ variant」のカード 1 枚だけ。0 枚・2 枚以上・公式戦使用不可のものは付け替えず、理由つきで一覧に出す。
# 付け替えは TeamMembershipWriter を通す（画面の保存と同じ経路）。カード変更の検査（現行・使用不可）、同キャラ、コスト、時限、各時点の検査し直しも同じ。
#   - 日付は各チームのシーズンの現在日（season.current_date）・phase は pre_game。契約（コスト区分）・コスト除外・表示名は今の値のまま
#   - 1 人ずつ書く。検査で止まった（Rejected・RecordInvalid）所属はその理由を一覧に出して飛ばし、ほかの所属は続ける
#   - 変更記録（team_membership_changes）は contract として足す。過去の記録（試合・登板）は書き換えない。カードが変わる投手の登板の保存値だけは、
#     writer の標準どおり変更の日（現在日）から作り直される
#   - シーズンの無いチームは変更記録が無いので、行のカードを直接書き換える
# dry-run は同じ経路を 1 つのトランザクションで流して最後に巻き戻す（検査の結果が実際の保存と同じに出る。DB は変わらない）。
# 戻す（revert）: 付け替えが足した変更記録を消して写しを作り直す。その変更が最新で、現在のカードが付け替え後のままの所属だけ戻す。
class PmCardSwap
  Row = Struct.new(
    :team_id, :team_name, :membership_id, :squad, :player_id, :player_name, :card_type, :variant,
    :from_card_id, :from_set, :to_card_id, :to_set, :status, :reason,
    :cost_before, :cost_after, :cost_changed, :content_changed, :time_limited, :warnings, :change_ids, :date, :phase,
    keyword_init: true
  )

  PLAN_HEADERS = %w[
    team_id team membership_id squad player_id player card_type variant
    from_card_id from_set to_card_id to_set status reason
    cost_before cost_after cost_changed content_changed time_limited warnings change_ids date phase
  ].freeze
  REVERT_HEADERS = %w[team_id membership_id player_id from_card_id to_card_id change_ids date phase].freeze

  CONTENT_ATTRIBUTES = %w[
    batting_table pitching_table speed bunt steal_start steal_end injury_rate starter_stamina relief_stamina
    is_relief_only is_closer handedness unique_traits injury_traits biorhythm_period batting_style_id pitching_style_id
    pinch_pitching_style_id catcher_pitching_style_id
  ].freeze

  # team_ids / membership_ids: 絞り込み（nil なら全部）。from_sets / to_sets: カードセット名（nil なら 現行外の PM 系 → 現行の PM 系）
  def initialize(team_ids: nil, membership_ids: nil, from_sets: nil, to_sets: nil, date: nil, commissioner: false)
    @team_ids = Array(team_ids).presence&.map(&:to_i)
    @membership_ids = Array(membership_ids).presence&.map(&:to_i)
    @from_sets = from_sets
    @to_sets = to_sets
    @date = date&.to_date
    @commissioner = commissioner
  end

  # 何を何に替えるか（読むだけ）。Row の配列。status は "swap"（付け替える）か "skip"（理由つき）
  def plan
    cost_list = Cost.current_cost
    from_ids = card_set_ids(@from_sets, current: false)
    to_ids = card_set_ids(@to_sets, current: true)
    memberships = TeamMembership.active.includes(:team, :player, player_card: :card_set)
                                .where(player_card_id: PlayerCard.where(card_set_id: from_ids).select(:id))
    memberships = memberships.where(team_id: @team_ids) if @team_ids
    memberships = memberships.where(id: @membership_ids) if @membership_ids

    memberships.order(:team_id, :id).map { |tm| plan_row(tm, to_ids, cost_list) }
  end

  # plan を実際に書く。dry_run なら巻き戻す。Row の配列（status が applied / rejected / skip）を返す
  def apply!(dry_run: true)
    rows = plan
    ActiveRecord::Base.transaction do
      rows.each { |row| apply_row!(row) if row.status == "swap" }
      raise ActiveRecord::Rollback if dry_run
    end
    rows.each { |row| row.status = "dry_run_ok" if dry_run && row.status == "applied" }
    rows
  end

  # 戻し用 CSV の行（Hash の配列）から戻す。dry_run なら巻き戻す。[{ membership_id:, status:, reason: }] を返す
  def self.revert!(entries, dry_run: true)
    results = []
    ActiveRecord::Base.transaction do
      entries.each { |entry| results << revert_one(entry) }
      raise ActiveRecord::Rollback if dry_run
    end
    results
  end

  def self.plan_csv(rows, io)
    csv = CSV.new(io)
    csv << PLAN_HEADERS
    rows.each do |r|
      csv << [ r.team_id, r.team_name, r.membership_id, r.squad, r.player_id, r.player_name, r.card_type, r.variant,
               r.from_card_id, r.from_set, r.to_card_id, r.to_set, r.status, r.reason,
               r.cost_before, r.cost_after, r.cost_changed, r.content_changed, r.time_limited, Array(r.warnings).join(" / "),
               Array(r.change_ids).join(" "), r.date, r.phase ]
    end
  end

  def self.revert_csv(rows, io)
    csv = CSV.new(io)
    csv << REVERT_HEADERS
    rows.select { |r| %w[applied dry_run_ok].include?(r.status) && r.to_card_id }.each do |r|
      csv << [ r.team_id, r.membership_id, r.player_id, r.from_card_id, r.to_card_id, Array(r.change_ids).join(" "), r.date, r.phase ]
    end
  end

  def self.revert_one(entry)
    tm = TeamMembership.find_by(id: entry["membership_id"])
    return { membership_id: entry["membership_id"], status: "skip", reason: "membership_missing" } unless tm

    to_id = entry["to_card_id"].to_i
    from_id = entry["from_card_id"].to_i
    return result_for(tm, "skip", "card_changed_since (now #{tm.player_card_id.inspect})") unless tm.player_card_id == to_id

    change_ids = entry["change_ids"].to_s.split.map(&:to_i)
    changes = TeamMembershipChange.where(id: change_ids)
    return result_for(tm, "skip", "changes_missing") unless changes.size == change_ids.size
    return result_for(tm, "skip", "changes_not_this_membership") unless changes.all? { |c| c.team_membership_id == tm.id }
    return result_for(tm, "skip", "later_changes_exist") if change_ids.any? && TeamMembershipChange.where(team_membership_id: tm.id).where("id > ?", change_ids.max).exists?

    changes.destroy_all
    team = tm.team
    RosterState.new(team).rebuild_cache!
    tm.reload
    # 変更記録が 1 件も残らない所属（シーズンの無いチーム・付け替えが初期の join から足した行）は写しが正なので、直接戻す
    if tm.player_card_id != from_id && !TeamMembershipChange.where(team_membership_id: tm.id).exists?
      tm.update_columns(player_card_id: from_id, updated_at: Time.current)
    end
    tm.reload
    return result_for(tm, "failed", "card_not_restored (now #{tm.player_card_id.inspect})") unless tm.player_card_id == from_id

    if entry["date"].present?
      outcome = PitcherHistoryRebuild.guarded(team_id: team.id, date: entry["date"].to_date, pitcher_ids: [ tm.player_id ])
      return result_for(tm, "restored", "pitcher_rebuild_failed: #{outcome.error.class}") unless outcome.ok?
    end
    result_for(tm, "restored", nil)
  end

  def self.result_for(tm, status, reason)
    { membership_id: tm.id, status: status, reason: reason }
  end
  private_class_method :result_for

  private

  def card_set_ids(names, current:)
    return CardSet.where(name: names).pluck(:id) if names.present?

    CardSet.where(is_current: current).where("set_type LIKE ?", "pm%").pluck(:id)
  end

  def plan_row(tm, to_ids, cost_list)
    from = tm.player_card
    row = Row.new(
      team_id: tm.team_id, team_name: tm.team.name, membership_id: tm.id, squad: tm.squad,
      player_id: tm.player_id, player_name: tm.player.name, card_type: from.card_type, variant: from.variant,
      from_card_id: from.id, from_set: from.card_set.name, cost_before: tm.selected_cost_value(cost_list), warnings: [], change_ids: []
    )

    targets = PlayerCard.where(card_set_id: to_ids, player_id: tm.player_id, card_type: from.card_type)
                        .select { |c| c.variant.to_s == from.variant.to_s }
    if targets.empty?
      return skip(row, "no_target#{twin_hint(tm, to_ids, from)}")
    elsif targets.size > 1
      return skip(row, "ambiguous_target (#{targets.map(&:id).join(',')})")
    end

    target = targets.first
    row.to_card_id = target.id
    row.to_set = target.card_set.name
    return skip(row, "target_official_use_prohibited") if target.official_use_prohibited

    probe = TeamMembership.new(player: tm.player, player_card: target, selected_cost_type: tm.selected_cost_type)
    row.cost_after = probe.selected_cost_value(cost_list)
    row.cost_changed = row.cost_after != row.cost_before
    row.content_changed = content_differs?(from, target)
    row.time_limited = target.availability_period_label
    row.status = "swap"
    row
  end

  def skip(row, reason)
    row.status = "skip"
    row.reason = reason
    row
  end

  # 同じキャラの別 Player に当て先があれば、手がかりとして一覧に書く（付け替えはしない）
  def twin_hint(tm, to_ids, from)
    return "" if tm.player.character_key.blank?

    twins = PlayerCard.joins(:player).where(card_set_id: to_ids, card_type: from.card_type, players: { character_key: tm.player.character_key })
                      .where.not(player_id: tm.player_id).to_a
    twins.empty? ? "" : " (same character, other player: #{twins.map { |c| "#{c.player.name} card #{c.id}" }.join(', ')})"
  end

  def content_differs?(a, b)
    return true if CONTENT_ATTRIBUTES.any? { |attr| a[attr] != b[attr] }

    signature(a) != signature(b)
  end

  def signature(card)
    [
      card.player_card_defenses.map { |d| [ d.position, d.error_rank, d.range_value, d.throwing, d.condition_id ] }.sort_by(&:to_s),
      card.player_card_traits.map { |t| [ t.trait_definition_id, t.condition_id, t.role ] }.sort_by(&:to_s),
      card.player_card_abilities.map { |t| [ t.ability_definition_id, t.condition_id, t.role ] }.sort_by(&:to_s)
    ]
  end

  def apply_row!(row)
    tm = TeamMembership.find(row.membership_id)
    team = tm.team
    season = team.season
    ActiveRecord::Base.transaction(requires_new: true) do
      if season
        write_with_changes!(row, tm, team, season)
      else
        row.date = nil
        tm.player_card_id = row.to_card_id
        tm.save!
      end
      tm.reload
      raise ActiveRecord::Rollback unless tm.player_card_id == row.to_card_id # 後日付の記録に上書きされた等。下で理由を付ける
    end
    tm.reload
    if tm.player_card_id == row.to_card_id
      row.status = "applied"
    else
      row.status = "not_applied"
      row.reason ||= "membership card is #{tm.player_card_id.inspect} after write (later-dated change record?)"
      row.change_ids = []
    end
  rescue TeamMembershipWriter::Rejected => e
    row.status = "rejected"
    row.reason = e.message
  rescue ActiveRecord::RecordInvalid => e
    row.status = "invalid"
    row.reason = e.record&.errors&.full_messages&.join(", ").presence || e.message
  end

  def write_with_changes!(row, tm, team, season)
    date = @date || season.current_date
    phase = SeasonRoster::DEFAULT_PHASE
    row.date = date
    row.phase = phase

    state = RosterState.new(team)
    point = state.at(date, phase)
    mine = point[tm.id]
    unless mine&.on_team && mine.player_card_id == row.from_card_id
      raise_skip!(row, "state_at_date_differs (on_team=#{mine&.on_team.inspect} card=#{mine&.player_card_id.inspect})")
    end
    if state.change_records(tm.id).any? { |c| c.effective_on > date }
      raise_skip!(row, "later_dated_change_records_exist")
    end

    players = point.values.select(&:on_team).map do |entry|
      tm_row = state.memberships.find { |m| m.id == entry.team_membership_id }
      {
        player_id: tm_row.player_id, selected_cost_type: entry.selected_cost_type,
        excluded_from_team_total: entry.excluded_from_team_total, display_name: entry.display_name,
        player_card_id: entry.team_membership_id == tm.id ? row.to_card_id : entry.player_card_id
      }
    end

    max_id = TeamMembershipChange.maximum(:id) || 0
    result = TeamMembershipWriter.new(team: team, user: nil, commissioner: @commissioner).update!(players, date: date, phase: phase)
    row.warnings = result.warnings
    row.change_ids = TeamMembershipChange.where(team_membership_id: tm.id).where("id > ?", max_id).order(:id).pluck(:id)
  end

  def raise_skip!(row, reason)
    row.reason = reason
    raise ActiveRecord::Rollback
  end
end
