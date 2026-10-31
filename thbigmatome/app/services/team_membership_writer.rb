# チーム編成（登録・契約・放出）の保存を、変更記録の追加として書く（cmd_1784 段2）。
#
# 設計: context/thbig-dugout-season-record-restructure-design.md §4.4 の 1・2・3・5。
#   - 送られた全員分の値と「その時点（日付 + 区分）の状態」を比べ、差を変更記録（team_membership_changes）に変える。
#       無かった選手 / 放出済みの選手   -> join（登録・再登録）
#       契約・カード・コスト除外・表示名が違う -> contract
#       送られなかった在籍中の選手       -> release（行は消さない。登板・離脱・昇降格の記録が指す先として残す）
#     値が同じ選手は記録しない。
#   - 放出する選手が 1軍なら、同じ時点に 2軍への降格を昇降格の変更記録に足す（放出 = 降格 + 在籍を外す。再登録で 1軍のまま戻らない）。
#   - 記録を足したあと、その時点以降の各時点・各試合日を検査し直す。コミッショナー以外は、この保存で新たに生じた（悪化した）違反があれば
#     保存を止めて違反した日付を返す。コミッショナーは警告つきで保存できる（いまの扱いと同じ）。チーム全体の合計コスト（200）は、
#     コスト表（cost_list_id）が渡された時に、書いた時点そのものを絶対の基準で検査する（いまの保存と同じ）。
#   - 保存のたびに team_memberships の写し（在籍・契約・squad）を作り直す。
#
# 記録がまったく無い行（移行前の行）に初めて書く時は、先にその行の今の値で初期の join 記録を足す（rake の初期記録と同じ日付の決め方）。
class TeamMembershipWriter
  # violations: [RosterConstraintChecker::Violation]
  class Rejected < StandardError
    attr_reader :violations

    def initialize(message, violations = [])
      super(message)
      @violations = violations
    end
  end

  Result = Struct.new(:warnings, :changes, keyword_init: true)

  def initialize(team:, user:, commissioner:, cost_list_id: nil, cost_list: Cost.current_cost)
    @team = team
    @season = team.season or raise ArgumentError, "season required"
    @user = user
    @commissioner = commissioner
    @cost_list_id = cost_list_id
    @cost_list = cost_list
  end

  # players: [{ player_id:, selected_cost_type:, excluded_from_team_total:, display_name:, player_card_id: }]（params でも Hash でもよい）
  # 戻り値は Result。warnings は文字列の配列（コミッショナーの超過警告）。changes は足した記録の件数 { join:, contract:, release: }
  def update!(players, date:, phase: SeasonRoster::DEFAULT_PHASE)
    date = date.to_date
    desired = normalize(players)
    counts = Hash.new(0)
    warnings = []

    ActiveRecord::Base.transaction do
      @team.lock!
      before = load_state
      point = before.at(date, phase)
      by_player = before.memberships.index_by(&:player_id)
      @initialized = Set.new

      before.memberships.each do |tm|
        entry = point.fetch(tm.id)
        next unless entry.on_team
        next if desired.key?(tm.player_id)

        release!(before, tm, entry, date, phase)
        counts[:release] += 1
      end

      desired.each_value do |values|
        tm = by_player[values[:player_id]]
        kind = if tm.nil?
          tm = create_membership!(values)
          "join"
        elsif !point.fetch(tm.id).on_team
          validate_rejoin!(tm)
          "join"
        elsif contract_differs?(point.fetch(tm.id), values)
          "contract"
        end
        next unless kind

        ensure_initial_join!(before, tm, date) if kind == "contract"
        record!(tm, kind, values, date, phase)
        counts[kind.to_sym] += 1
      end

      after = load_state
      check!(before, after, date, phase, warnings)
      after.rebuild_cache!
    end

    Result.new(warnings: warnings, changes: counts)
  end

  private

  def normalize(players)
    desired = {}
    Array(players).each do |p|
      id = p[:player_id].to_i
      desired[id] = {
        player_id: id,
        selected_cost_type: p[:selected_cost_type],
        excluded_from_team_total: p[:excluded_from_team_total] || false,
        display_name: p[:display_name].presence,
        player_card_id: p[:player_card_id].presence&.to_i
      }
    end
    desired
  end

  def load_state
    memberships = @team.all_team_memberships
                       .preload(:season_rosters, :team_membership_changes, player: :cost_players, player_card: [ :card_set, :player_card_defenses ])
                       .to_a
    RosterState.new(@team, memberships: memberships)
  end

  def contract_differs?(entry, values)
    entry.selected_cost_type != values[:selected_cost_type] ||
      entry.player_card_id != values[:player_card_id] ||
      entry.excluded_from_team_total != values[:excluded_from_team_total] ||
      entry.display_name != values[:display_name]
  end

  # 新しい選手を在籍させる。行の値は送られた値（写しは保存の最後に作り直す）。検証（監督の他チームとの重複など）はいまの保存と同じ
  def create_membership!(values)
    tm = @team.all_team_memberships.new(player_id: values[:player_id], squad: "second")
    tm.skip_commissioner_validation = true if @commissioner
    tm.assign_attributes(values.slice(:selected_cost_type, :excluded_from_team_total, :display_name, :player_card_id))
    tm.save!
    tm
  end

  # 放出済みの選手の再登録も、新しく登録するのと同じ検証を通す（監督の他チームとの重複）
  def validate_rejoin!(tm)
    return if @commissioner

    probe = TeamMembership.new(team: @team, player_id: tm.player_id, selected_cost_type: tm.selected_cost_type)
    return if probe.valid?(:create)

    raise ActiveRecord::RecordInvalid, probe
  end

  # 記録がまったく無い行に、その行の今の値で初期の join を足す。日付は最初の昇降格の日とシーズン開始日の早い方、書く日付がそれより前ならその日
  def ensure_initial_join!(state, tm, date)
    return if @initialized.include?(tm.id)
    return unless state.change_records(tm.id).empty?

    @initialized << tm.id
    first_roster = tm.season_rosters.map(&:registered_on).min
    season_start = @season.season_schedules.minimum(:date)
    joined_on = [ TeamMembershipChange.initial_join_date(first_roster, season_start), date ].compact.min
    TeamMembershipChange.create!(
      team_membership: tm, season: @season, kind: "join", effective_on: joined_on, phase: SeasonRoster::DEFAULT_PHASE,
      selected_cost_type: tm.selected_cost_type, player_card_id: tm.player_card_id,
      excluded_from_team_total: tm.excluded_from_team_total, display_name: tm.display_name,
      recorded_by_user_id: @user&.id
    )
  end

  def record!(tm, kind, values, date, phase)
    TeamMembershipChange.create!(
      team_membership: tm, season: @season, kind: kind, effective_on: date, phase: phase,
      selected_cost_type: values[:selected_cost_type], player_card_id: values[:player_card_id],
      excluded_from_team_total: values[:excluded_from_team_total], display_name: values[:display_name],
      recorded_by_user_id: @user&.id
    )
  end

  def release!(state, tm, entry, date, phase)
    ensure_initial_join!(state, tm, date)
    # 放出は降格を伴う。1軍のまま在籍を外すと、再登録した時に 1軍で戻ってしまう
    if entry.squad == "first"
      SeasonRoster.create!(season: @season, team_membership: tm, squad: "second", registered_on: date, phase: phase,
                           recorded_by_user_id: @user&.id)
    end
    record!(tm, "release", {
      selected_cost_type: entry.selected_cost_type, player_card_id: entry.player_card_id,
      excluded_from_team_total: entry.excluded_from_team_total, display_name: entry.display_name
    }, date, phase)
  end

  # 書いた時点以降を検査し直す。書いた時点のチーム全体の合計コストだけは絶対の基準（いまの保存と同じ）、そのほかは新たに生じた・悪化した違反だけ
  def check!(before, after, date, phase, warnings)
    total_list = @cost_list_id ? (Cost.find_by(id: @cost_list_id) || @cost_list_id.to_i) : nil
    checker = RosterConstraintChecker.new(team: @team, season: @season, cost_list: @cost_list, team_total_cost_list: total_list)

    found = checker.new_violations(before, after, [ date, phase ])
    if total_list
      absolute = checker.team_total_violations(after, date, phase)
      found = absolute + found.reject { |v| absolute.any? { |a| a.key == v.key } }
      # チーム全体の合計コストは、超えたまま続く後の時点ごとに同じ警告を重ねない（最初の時点だけ）
      first_total = found.find { |v| v.kind == "team_total_cost" }
      found = found.reject { |v| v.kind == "team_total_cost" && !v.equal?(first_total) }
    end
    return if found.empty?

    if @commissioner
      found.each { |v| warnings << (v.date == date && v.phase == phase ? v.message : RosterConstraintChecker.dated_message(v)) }
    else
      first = found.first
      message = first.date == date && first.phase == phase ? first.message : RosterConstraintChecker.dated_message(first)
      raise Rejected.new(message, found)
    end
  end
end
