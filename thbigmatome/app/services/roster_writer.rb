# 昇降格の変更記録を書く・消す（cmd_1784 段1）。
#
# 設計: context/thbig-dugout-season-record-restructure-design.md §4.4。
#   1. 日付と区分（pre_game / in_game / post_game）を受ける。
#   2. 差し込み・削除のあと、その時点以降の各時点・各試合日について人数・コスト・外の世界枠・クールダウンを検査し直す。
#      違反があれば、コミッショナー以外は保存を止めて違反した日付を返す（Rejected#violations）。コミッショナーは警告つきで保存する。
#   3. 保存のたびに team_memberships.squad の写しを変更記録の最新の状態に作り直す（現在日カーソルとの一致で条件づけない）。
#
# 検査の考え方:
#   - 書き込んだ時点そのもの（対象日・対象区分）は、いままでどおり絶対の基準で検査する（試合日の最低人数・上限 29・コスト・外の世界枠）。
#   - それより後の時点は「この保存で新たに生じた、または悪化した違反」だけを止める。保存の前から外れていた日まで止めると、
#     無関係な保存が通らなくなる（初期登録の途中で後の試合日がまだ最低人数に届かない、など）。
#   - 直接の昇格のクールダウンと再調整中の昇格は、コミッショナーでも止める（いままでどおり）。
class RosterWriter
  # violations: [RosterConstraintChecker::Violation]（空のこともある。メッセージだけの拒否）
  class Rejected < StandardError
    attr_reader :violations

    def initialize(message, violations = [])
      super(message)
      @violations = violations
    end
  end

  Result = Struct.new(:warnings, :violations, keyword_init: true)

  # 保存の対象外にする squad の値
  SQUADS = %w[first second].freeze

  def initialize(team:, user:, commissioner:, cost_list: Cost.current_cost)
    @team = team
    @season = team.season
    @user = user
    @commissioner = commissioner
    @cost_list = cost_list
  end

  # roster_updates: [{ team_membership_id:, squad: }]（params でも Hash でもよい）。戻り値は Result
  def update!(roster_updates, date:, phase: SeasonRoster::DEFAULT_PHASE)
    date = date.to_date
    updates = Array(roster_updates)
    validate_updates!(updates)

    warnings = []
    ActiveRecord::Base.transaction do
      @team.lock!
      before = load_state
      point = before.at(date, phase)
      memberships = before.memberships.index_by(&:id)

      updates.each do |update|
        membership = memberships[update[:team_membership_id].to_i] or
          raise ActiveRecord::RecordNotFound, "Couldn't find TeamMembership with 'id'=#{update[:team_membership_id]}"
        new_squad = update[:squad].to_s
        current_squad = point.fetch(membership.id).squad
        next if current_squad == new_squad

        if new_squad == "first"
          reject_if_not_promotable!(membership, point.fetch(membership.id), date)
        end
        record!(membership, new_squad, date, phase)
      end

      after = load_state
      checker = RosterConstraintChecker.new(team: @team, season: @season, cost_list: @cost_list)
      apply_target_point_check!(checker, after, date, phase, warnings)
      apply_later_point_check!(checker, before, after, [ date, phase ], warnings, after_target_only: true)
      after.rebuild_squad_cache!
    end

    Result.new(warnings: warnings, violations: [])
  end

  # 昇降格の記録を消す。消したあとも、その時点以降を検査し直す
  def destroy!(entry)
    warnings = []
    ActiveRecord::Base.transaction do
      @team.lock!
      before = load_state
      from_point = [ entry.registered_on, entry.phase ]
      entry.destroy!

      after = load_state
      checker = RosterConstraintChecker.new(team: @team, season: @season, cost_list: @cost_list)
      apply_later_point_check!(checker, before, after, from_point, warnings, after_target_only: false)
      after.rebuild_squad_cache!
    end

    Result.new(warnings: warnings, violations: [])
  end

  private

  # 検査で使う関連（コスト・カード・離脱・変更記録）を 1 回で読み込んだ状態
  def load_state
    memberships = @team.team_memberships
                       .preload(:season_rosters, :player_absences, player: :cost_players, player_card: [ :card_set, :player_card_defenses ])
                       .to_a
    RosterState.new(@team, memberships: memberships)
  end

  def validate_updates!(updates)
    ids = updates.map { |u| u[:team_membership_id].to_s.presence }.compact
    duplicates = ids.tally.select { |_id, count| count > 1 }.keys
    raise Rejected, "Duplicate team_membership_id in roster_updates: #{duplicates.join(', ')}" if duplicates.any?

    invalid = updates.reject { |u| SQUADS.include?(u[:squad].to_s) }
    raise Rejected, "squad must be one of: #{SQUADS.join(', ')}" if invalid.any?
  end

  def reject_if_not_promotable!(membership, entry, date)
    # 再調整中の選手は、コミッショナーでも 1軍登録できない
    absence = active_absence(membership, date)
    if absence && absence.absence_type == "reconditioning"
      raise Rejected, "#{membership.player.name}は再調整中のため1軍登録できません。"
    end

    # クールダウン（降格から 10 日）。同日の昇降格は免除。コミッショナーでも維持される
    if entry.cooldown_until && !entry.same_day_exempt
      raise Rejected, "Player #{membership.player.name} is on cooldown until #{entry.cooldown_until}"
    end
  end

  def active_absence(membership, date)
    membership.player_absences.find do |pa|
      end_date = pa.effective_end_date
      date >= pa.start_date && (end_date.nil? || date < end_date)
    end
  end

  def record!(membership, squad, date, phase)
    SeasonRoster.create!(
      season: @season,
      team_membership: membership,
      squad: squad,
      registered_on: date,
      phase: phase,
      recorded_by_user_id: @user&.id
    )
  end

  # 書き込んだ時点そのものの絶対の検査。コミッショナーは警告にして保存する
  def apply_target_point_check!(checker, state, date, phase, warnings)
    violations = checker.point_violations(state, date, phase)
    return if violations.empty?

    if @commissioner
      violations.each { |v| warnings << warning_for(v, dated: false) }
    else
      raise Rejected.new(violations.first.message, violations)
    end
  end

  # それより後の時点の、新たに生じた（悪化した）違反。after_target_only: true なら書き込んだ時点そのものは含めない（絶対の検査済み）
  def apply_later_point_check!(checker, before, after, from_point, warnings, after_target_only:)
    found = checker.new_violations(before, after, from_point)
    found = found.reject { |v| v.kind != "cooldown" && v.date == from_point[0] && v.phase == from_point[1] } if after_target_only
    return if found.empty?

    if @commissioner
      found.each { |v| warnings << warning_for(v, dated: true) }
    else
      raise Rejected.new(RosterConstraintChecker.dated_message(found.first), found)
    end
  end

  def warning_for(violation, dated:)
    {
      type: "commissioner_override",
      message: dated ? RosterConstraintChecker.dated_message(violation) : violation.message,
      kind: violation.kind,
      date: violation.date.to_s,
      phase: violation.phase
    }
  end
end
