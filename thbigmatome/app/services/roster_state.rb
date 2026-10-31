# チームの「ある時点の状態」を、昇降格の変更記録（season_rosters）から導く（cmd_1784 段1）。
#
# 設計: context/thbig-dugout-season-record-restructure-design.md §4.1・§4.3 と、末尾の追記（同区分の連続記録は畳む）。
# 読む側（ロスター表示・疲労一覧の 1軍判定・コミッショナーのダッシュボード・クールダウン）はここを通す。
#
# 時点は「日付 + 区分」の組。区分の順は pre_game < in_game < post_game（SeasonRoster::PHASES）。
# 時点 (D, p) の状態は、(registered_on, phase) が (D, p) 以下の記録のうち最後のもの。同じ時点の中は作成順（created_at, id）。
#
# - 記録が無い選手は second（team_memberships.squad の写しには倒さない）。
# - 直前と同じ区分への記録（状態が変わらない重複。設計書 §1.3 S3）は畳む。連続する同じ区分は最初の 1 件だけ残す。
#   クールダウンの降格日・昇格日はこの畳んだ記録で数える（畳まないと偽陽性になる）。
# - 在籍・契約・カード・コスト除外・表示名は、チーム編成の変更記録（team_membership_changes。cmd_1784 段2。設計書 §4.3）から導く。
#   時点 (D, p) の値は、(effective_on, phase) が (D, p) 以下の記録のうち最後のもの（join / contract は在籍中、release は放出済み）。
#   - 最初の記録より前の時点は、まだチームにいない（on_team = false）。
#   - 記録がまったく無い行（シーズンの無いチーム、移行前の行）は team_memberships の今の値を全時点の値として使う。
#   - 放出済みの選手は on_team = false。1軍の人数・コストには数えず、squad は second として返す。
# - 離脱は段3 の範囲。今は team_memberships の今の値をそのまま使う。
class RosterState
  DEFAULT_PHASE = SeasonRoster::DEFAULT_PHASE
  COOLDOWN_DAYS = 10 # 降格から再登録できるまでの日数（ルール 03 §3.6）

  Record = Struct.new(:id, :team_membership_id, :registered_on, :phase, :squad, :created_at, keyword_init: true) do
    def point_key
      [ registered_on, SeasonRoster.phase_rank(phase) ]
    end

    def sort_key
      [ registered_on, SeasonRoster.phase_rank(phase), created_at || Time.zone.at(0), id || Float::INFINITY ]
    end
  end

  # チーム編成の変更記録 1 件の写し（TeamMembershipChange）
  Change = Struct.new(:id, :team_membership_id, :effective_on, :phase, :kind, :selected_cost_type, :player_card_id,
                      :excluded_from_team_total, :display_name, :created_at, keyword_init: true) do
    def point_key
      [ effective_on, SeasonRoster.phase_rank(phase) ]
    end

    def sort_key
      [ effective_on, SeasonRoster.phase_rank(phase), created_at || Time.zone.at(0), id || Float::INFINITY ]
    end

    def on_team?
      kind != "release"
    end
  end

  Entry = Struct.new(:team_membership_id, :on_team, :squad, :selected_cost_type, :player_card_id, :excluded_from_team_total, :display_name,
                     :cooldown_until, :same_day_exempt, :demotion_date, keyword_init: true) do
    def first?
      on_team && squad == "first"
    end
  end

  DEFAULT_CARD_INCLUDES = [ :card_set, :player_card_defenses ].freeze

  NO_COOLDOWN = { cooldown_until: nil, same_day_exempt: false, demotion_date: nil }.freeze

  attr_reader :team, :memberships

  # team の date・phase 時点の状態 { team_membership_id => Entry }
  def self.at(team, date, phase = DEFAULT_PHASE)
    new(team).at(date, phase)
  end

  # team_memberships.squad の写しを、変更記録の最新の状態に作り直す。変わった行を [[membership, 旧, 新], ...] で返す
  def self.rebuild_squad_cache!(team, state: nil)
    state ||= new(team)
    state.rebuild_squad_cache!
  end

  # memberships: 渡せば team.all_team_memberships の代わりに使う（season_rosters・team_membership_changes を preload 済みなら追加の問い合わせをしない）。
  #   既定は放出済みを含む全行（過去の時点には、後で放出された選手もいる）
  # card_includes: 時点の契約でカードが変わる行の PlayerCard を読み込む時の preload
  def initialize(team, memberships: nil, card_includes: DEFAULT_CARD_INCLUDES)
    @team = team
    @memberships = (memberships || team.all_team_memberships.to_a).to_a
    @card_includes = card_includes
    load_records
  end

  def self.parse_phase(value)
    return DEFAULT_PHASE if value.blank?

    phase = value.to_s
    raise ArgumentError, "invalid phase: #{phase}" unless SeasonRoster::PHASES.include?(phase)

    phase
  end

  def at(date, phase = DEFAULT_PHASE)
    key = point_key(date, phase)
    memberships.to_h { |tm| [ tm.id, build_entry(tm, key) ] }
  end

  def entry(team_membership_id, date, phase = DEFAULT_PHASE)
    tm = memberships.find { |m| m.id == team_membership_id }
    tm && build_entry(tm, point_key(date, phase))
  end

  # 時点の 1軍の team_membership（放出済み・まだ在籍していない選手は含めない）
  def first_memberships(date, phase = DEFAULT_PHASE)
    key = point_key(date, phase)
    memberships.select { |tm| on_team_at?(tm, key) && squad_at(tm.id, key) == "first" }
  end

  # 時点の 1軍の、その時点の契約・カードを反映した TeamMembership（view）。コスト・外の世界枠・役割の計算に使う
  def first_views(date, phase = DEFAULT_PHASE)
    key = point_key(date, phase)
    first_memberships(date, phase).map { |tm| view(tm, build_entry(tm, key)) }
  end

  # 時点の在籍中の team_membership
  def on_team_memberships(date, phase = DEFAULT_PHASE)
    key = point_key(date, phase)
    memberships.select { |tm| on_team_at?(tm, key) }
  end

  # entry の契約・カード・コスト除外・表示名を反映した TeamMembership。値が行と同じなら行そのもの。
  # 返す view は未保存・読み取り専用で、player・player_card は読み込み済みのものを使う（absences など他の関連は持たない）
  def view(tm, entry)
    return tm if entry.selected_cost_type == tm.selected_cost_type && entry.player_card_id == tm.player_card_id &&
                 entry.excluded_from_team_total == tm.excluded_from_team_total && entry.display_name == tm.display_name

    TeamMembership.new(
      id: tm.id, team_id: tm.team_id, squad: entry.squad,
      selected_cost_type: entry.selected_cost_type, excluded_from_team_total: entry.excluded_from_team_total,
      display_name: entry.display_name, player: tm.player,
      player_card: entry.player_card_id ? card_for(tm, entry.player_card_id) : nil
    ).tap(&:readonly!)
  end

  # 変更記録 [Change, ...]（並びは時点順）
  def change_records(team_membership_id)
    @changes.fetch(team_membership_id, [])
  end

  # 記録の最後（日付・区分を問わない）の状態 { team_membership_id => "first" | "second" }
  def latest_squads
    memberships.to_h { |tm| [ tm.id, @collapsed[tm.id].last&.squad || "second" ] }
  end

  # 写し（squad・on_team・契約・カード・コスト除外・表示名）を変更記録の最新の状態に作り直す
  def rebuild_cache!
    rebuild_squad_cache!
    rebuild_membership_cache!
  end

  # 在籍・契約の写しを、チーム編成の変更記録の最新の状態に作り直す。変わった行を [[membership, { 列 => [旧, 新] }], ...] で返す。
  # 記録が無い行は触らない（行の値がそのまま正）
  def rebuild_membership_cache!
    changed = []
    memberships.each do |tm|
      last = @changes[tm.id].last
      next unless last

      wanted = {
        on_team: last.on_team?, selected_cost_type: last.selected_cost_type, player_card_id: last.player_card_id,
        excluded_from_team_total: last.excluded_from_team_total, display_name: last.display_name
      }
      diff = wanted.reject { |column, value| tm[column] == value }
      next if diff.empty?

      changed << [ tm, diff.to_h { |column, value| [ column, [ tm[column], value ] ] } ]
      tm.update_columns(diff.merge(updated_at: Time.current))
    end
    changed
  end

  def rebuild_squad_cache!
    latest = latest_squads
    changed = []
    memberships.each do |tm|
      next if tm.squad == latest[tm.id]

      changed << [ tm, tm.squad, latest[tm.id] ]
      # 写しの作り直しなので、契約の値などの検証は通さない（古い値の行があっても止めない）
      tm.update_columns(squad: latest[tm.id], updated_at: Time.current)
    end
    changed
  end

  # 畳んだ記録 [Record, ...]（並びは時点順）
  def collapsed_records(team_membership_id)
    @collapsed.fetch(team_membership_id, [])
  end

  # 記録のある時点 [[date, phase], ...]（昇降格・チーム編成の記録。重複なし・昇順）
  def record_points
    (@collapsed.values.flatten.map { |r| [ r.registered_on, r.phase ] } +
      @changes.values.flatten.map { |c| [ c.effective_on, c.phase ] }).uniq
      .sort_by { |date, phase| [ date, SeasonRoster.phase_rank(phase) ] }
  end

  # 畳んだ記録の上で、クールダウン（降格から 10 日）に掛かった昇格 { [team_membership_id, 昇格日, 区分] => { days_short:, demotion_date: } }
  # 降格の前に昇格が無い（最初から 2軍）、降格と昇格が同じ日（同日の昇降格は免除）は数えない。
  def cooldown_violations
    result = {}
    @collapsed.each do |tm_id, list|
      list.each_with_index do |promo, i|
        next unless promo.squad == "first" && i >= 2

        demotion = list[i - 1]
        previous_promotion = list[i - 2]
        next if previous_promotion.registered_on == demotion.registered_on

        days_short = (demotion.registered_on + COOLDOWN_DAYS - promo.registered_on).to_i
        next unless days_short.positive?

        result[[ tm_id, promo.registered_on, promo.phase ]] = { days_short: days_short, demotion_date: demotion.registered_on }
      end
    end
    result
  end

  private

  def point_key(date, phase)
    [ date.to_date, SeasonRoster.phase_rank(phase) ]
  end

  def load_records
    ids = memberships.map(&:id)
    loaded = memberships.all? { |tm| tm.association(:season_rosters).loaded? }
    rows = if loaded
      memberships.flat_map { |tm| tm.season_rosters.to_a }
    else
      SeasonRoster.where(team_membership_id: ids).to_a
    end
    grouped = rows.map do |r|
      Record.new(id: r.id, team_membership_id: r.team_membership_id, registered_on: r.registered_on, phase: r.phase,
                 squad: r.squad, created_at: r.created_at)
    end.group_by(&:team_membership_id)

    @collapsed = ids.index_with do |id|
      sorted = (grouped[id] || []).sort_by(&:sort_key)
      sorted.each_with_object([]) { |r, kept| kept << r if kept.empty? || kept.last.squad != r.squad }
    end

    load_changes(ids)
  end

  def load_changes(ids)
    loaded = memberships.all? { |tm| tm.association(:team_membership_changes).loaded? }
    rows = if loaded
      memberships.flat_map { |tm| tm.team_membership_changes.to_a }
    else
      TeamMembershipChange.where(team_membership_id: ids).to_a
    end
    grouped = rows.map do |c|
      Change.new(id: c.id, team_membership_id: c.team_membership_id, effective_on: c.effective_on, phase: c.phase, kind: c.kind,
                 selected_cost_type: c.selected_cost_type, player_card_id: c.player_card_id,
                 excluded_from_team_total: c.excluded_from_team_total, display_name: c.display_name, created_at: c.created_at)
    end.group_by(&:team_membership_id)
    @changes = ids.index_with { |id| (grouped[id] || []).sort_by(&:sort_key) }
  end

  # 時点 key の変更記録。記録のある行で最初の記録より前なら nil。記録がまったく無い行は :none
  def change_at(tm, key)
    list = @changes[tm.id]
    return :none if list.empty?

    i = last_index_at(list, key)
    i ? list[i] : nil
  end

  def on_team_at?(tm, key)
    change = change_at(tm, key)
    return tm.on_team if change == :none

    !change.nil? && change.on_team?
  end

  def card_for(tm, player_card_id)
    return tm.player_card if tm.player_card_id == player_card_id

    @cards ||= PlayerCard.includes(*@card_includes).where(id: @changes.values.flatten.filter_map(&:player_card_id).uniq).index_by(&:id)
    @cards[player_card_id] || PlayerCard.includes(*@card_includes).find(player_card_id)
  end

  # key 以下の最後の畳んだ記録の添字。無ければ nil
  def last_index_at(list, key)
    return nil if list.empty?

    index = list.bsearch_index { |r| (r.point_key <=> key) > 0 }
    return list.size - 1 if index.nil?
    return nil if index.zero?

    index - 1
  end

  def squad_at(team_membership_id, key)
    list = @collapsed[team_membership_id]
    i = last_index_at(list, key)
    i ? list[i].squad : "second"
  end

  def build_entry(tm, key)
    list = @collapsed[tm.id]
    i = last_index_at(list, key)
    contract = contract_values(tm, key)
    Entry.new(
      team_membership_id: tm.id,
      squad: contract[:on_team] && i ? list[i].squad : "second",
      **contract,
      **cooldown_for(list, i, key)
    )
  end

  # 時点 key の在籍・契約・カード・コスト除外・表示名
  def contract_values(tm, key)
    change = change_at(tm, key)
    if change == :none
      return { on_team: tm.on_team, selected_cost_type: tm.selected_cost_type, player_card_id: tm.player_card_id,
               excluded_from_team_total: tm.excluded_from_team_total, display_name: tm.display_name }
    end

    # まだチームにいない時点は在籍なし。値は最初の記録のものを返す（呼び出し側は on_team を見て捨てる）
    source = change || @changes[tm.id].first
    { on_team: !change.nil? && change.on_team?, selected_cost_type: source.selected_cost_type, player_card_id: source.player_card_id,
      excluded_from_team_total: source.excluded_from_team_total, display_name: source.display_name }
  end

  # 降格から 10 日。最後の降格（key 以下の最後の 2軍の記録）の前に昇格があれば対象。降格と同じ日の昇格だったなら same_day_exempt
  def cooldown_for(list, last_index, key)
    return NO_COOLDOWN unless last_index

    d = (0..last_index).reverse_each.find { |j| list[j].squad == "second" }
    return NO_COOLDOWN if d.nil? || d.zero?

    demotion = list[d]
    previous_promotion = list[d - 1]
    cooldown_end = demotion.registered_on + COOLDOWN_DAYS
    return NO_COOLDOWN unless key[0] < cooldown_end

    {
      cooldown_until: cooldown_end,
      same_day_exempt: previous_promotion.registered_on == demotion.registered_on,
      demotion_date: demotion.registered_on
    }
  end
end
