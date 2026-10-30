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
# - 契約・離脱は段2・段3 の範囲。今は team_memberships の今の値をそのまま使う（on_team は常に true）。
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

  Entry = Struct.new(:team_membership_id, :on_team, :squad, :selected_cost_type, :player_card_id, :excluded_from_team_total,
                     :cooldown_until, :same_day_exempt, :demotion_date, keyword_init: true) do
    def first?
      squad == "first"
    end
  end

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

  # memberships: 渡せば team.team_memberships の代わりに使う（season_rosters を preload 済みなら追加の問い合わせをしない）
  def initialize(team, memberships: nil)
    @team = team
    @memberships = (memberships || team.team_memberships.to_a).to_a
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

  # 時点の 1軍の team_membership
  def first_memberships(date, phase = DEFAULT_PHASE)
    key = point_key(date, phase)
    memberships.select { |tm| squad_at(tm.id, key) == "first" }
  end

  # 記録の最後（日付・区分を問わない）の状態 { team_membership_id => "first" | "second" }
  def latest_squads
    memberships.to_h { |tm| [ tm.id, @collapsed[tm.id].last&.squad || "second" ] }
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

  # 記録のある時点 [[date, phase], ...]（重複なし・昇順）
  def record_points
    @collapsed.values.flatten.map { |r| [ r.registered_on, r.phase ] }.uniq
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
    Entry.new(
      team_membership_id: tm.id,
      on_team: true,
      squad: i ? list[i].squad : "second",
      selected_cost_type: tm.selected_cost_type,
      player_card_id: tm.player_card_id,
      excluded_from_team_total: tm.excluded_from_team_total,
      **cooldown_for(list, i, key)
    )
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
