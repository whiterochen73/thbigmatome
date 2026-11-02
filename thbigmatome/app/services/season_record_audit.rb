# シーズン記録の食い違いを数える点検の道具（cmd_1784 段0。読むだけ）。
#
# 設計: context/thbig-dugout-season-record-restructure-design.md §1.3（S1・S2・S7・S8・S9・S10・S11・S12）と §5.1 段0・段3・§5.3。
# 以後の段（昇降格の日付の一本化ほか）の移行前後で、同じ道具を回して件数と明細を突き合わせる。
#
# DB へは一切書かない（SELECT のみ。トランザクションも開かない）。S8c の再計算も PitcherHistoryRebuild を
# apply: false で使うので書かない。
#
# 使い方: rake season_records:audit（lib/tasks/season_records.rake）
class SeasonRecordAudit
  # 明細 1 行。item は項目コード、category は項目内の分類、ref は元になった行の id（無ければ nil）
  Finding = Struct.new(:item, :category, :team_id, :player_id, :date, :ref, :evidence, keyword_init: true)

  # 項目コードと、この道具が採った定義（出力の見出しに出す）。件数を比べる時は定義が同じことを確かめる。
  ITEMS = {
    "S1" => [ "写し（team_memberships.squad）と昇降格の変更記録が合わない選手",
              "昇降格の記録がある選手のうち、記録を (registered_on, created_at, id) 順に並べた最後の squad が team_memberships.squad と違う。" \
              "カテゴリ: at_current_date = 現在日カーソル時点の squad でも写しと違う（ロスター画面と写しが食い違う）/ future_record_only = 現在日カーソルより後の日付の記録のせいで違うだけ。" ],
    "S2a" => [ "日付順と逆に差し込まれた昇降格の記録",
               "同じ選手で、後から作られた記録（id が大きい）の registered_on が、先に作られた記録より前。逆転の組に含まれる記録をすべて数える" \
               "（カテゴリ: inserted_later = 後から差し込まれた側 / overtaken = 追い越された側）。" ],
    "S2b" => [ "1軍人数が規定を外れた日",
               "シーズンの日程の日付と昇降格の記録の日付のうち、その日の 1軍が 29 人超（over_max）。記録が無い選手は 2軍とみなす（写しには倒さない）。" \
               "試合日（SeasonSchedule::GAME_DATE_TYPES = game_day / interleague_game_day / playoff_day。ノーゲームの日も含む）で、チームの最初の昇降格の記録の日以降かつシーズン初日（日程の最初の日）でなく、" \
               "1軍が最低人数（config/cost_limits.yml）未満（under_min）。コスト・外の世界枠は過去の契約・コスト表が復元できないため数えない（設計書 §8）。" ],
    "S2c" => [ "クールダウン（再登録不可 10 日）違反の昇格",
               "2軍→1軍の記録で、直前の降格（2軍の記録）の日から 10 日未満。降格の前の昇格が降格と同日なら免除（CooldownCalculable と同じ）。" \
               "直前と同じ区分への記録（状態が変わらない重複）は降格・昇格に数えない。" \
               "AMB-24 により試合日の昇降格そのものは違反に数えない。" ],
    "S7" => [ "1軍でない日の登板",
              "登板（pitcher_game_states）の試合日時点で、その投手のチーム内の最新の昇降格の記録が 2軍（category: second）、" \
              "または試合日以前に記録が無い（unregistered）。区切りは /same_day_demoted（同日に抹消の記録）・" \
              "/promoted_next_day（翌日に昇格の記録）・/other。離脱中かどうかは見ない。" \
              "段3 以降、保存時には止めず警告にして保存し（設計書 §7 判断 5）、試合日ページの要確認の帯に出る。この項目は過去分の件数で、段3 では減らない" \
              "（昇降格の日付か登板の入力を直した分だけ減る）。" ],
    "S8a" => [ "日付順より後に入力された試合日",
               "チームの登板が試合日ごとの束になっていて、その束の最初の入力（created_at, id）が、より後の日付の束より遅い試合日。" ],
    "S8b" => [ "日付順より後に入力された登板",
               "同じチーム・同じ投手で、より後の日付の登板が先に入力されていた登板（前の登板に依存する保存値が古くなりうる）。カテゴリは role。" ],
    "S8c" => [ "保存値が今の再計算と食い違う先発登板",
               "PitcherHistoryRebuild を試運転（apply: false）で回し、結果区分が変わる（changed）、疲労Pだけ変わる（fatigue_only）、" \
               "連続中4日回数だけ変わる（consecutive_only）先発登板。S8a・S8b で『古くなりうる』ものが実際に古いかの確認。" ],
    "S9" => [ "試合前の離脱の開始日が、その投手の登板日と同じ",
              "登板した日と同じ日を開始日とする離脱のうち、区分が pre_game（試合前）のもの。pre_game の離脱はその日から離脱中なので、" \
              "その投手は登板記録の候補から外れ、同じ日の登板と食い違う。試合中の負傷だった入力なら、区分を in_game（試合中）に直す。" \
              "区分が in_game の同日の離脱は正常（翌日から離脱）で数えず、参考に件数だけ出す。カテゴリは離脱の種別。" ],
    "S10" => [ "日程の種別に no_game が残っている日（ノーゲームの表し方が 2 通りある）",
               "段4 でノーゲームは真偽値 no_game に一本化した（種別 no_game は新たに作れない）。種別 no_game の日を数える。" \
               "type_no_game_flag_false = 種別だけ no_game（サーバの勝敗判定は通常の試合として見る。rake season_records:normalize_no_game_dates を流す前）/ " \
               "type_no_game_flag_true = 種別も真偽値も no_game（種別だけ戻し損ねた日）。evidence に、その日の登板件数を出す。" \
               "段4 の適用後は 0 件になる。真偽値だけが真の日は正常（ノーゲームの日の正しい形）なので数えない。" ],
    "S11" => [ "試合日でない種別の日の登板",
               "登板の試合日の日程の種別が SeasonSchedule::GAME_DATE_TYPES（game_day / interleague_game_day / playoff_day）のどれでもない登板。" \
               "カテゴリは種別（日程の行が無ければ no_schedule）。種別 no_game の日（段4 の適用前）はここにも入る。" \
               "段4 は雨天中止・移動日・予備日の日の登板には触らない（入力誤りか種別の付け間違いか区別できないため）。一覧に出すだけで、" \
               "予備日などの種別のまま真偽値 no_game が立った日の登板もここに残る。" ],
    "S12" => [ "日程の行に紐づいていない登板",
               "登板の season_schedule_id が空、または（チーム, 試合日）から引いた日程の行と違う。カテゴリ: unlinked/linkable = 日程の行が 1 件あるのに空" \
               "（rake season_records:link_pitcher_schedules を流す前）/ unlinked/no_schedule = 対応する日程の行が無い（行は作らない）/ " \
               "unlinked/ambiguous = 同じ日に日程の行が複数 / mismatch = 紐づけ先が引いた行と違う。" ]
  }.freeze

  # 試合日とみなす種別（S11）。段4 でサーバの定義を 1 つにした（SeasonSchedule::GAME_DATE_TYPES）。
  # 「試合数に数える日」はそのうち真偽値 no_game でない日（SeasonSchedule.counted_games）。出力に現状を出すための記録。
  GAME_DAY_SETS = {
    "試合日とみなす種別（1軍最低人数の検査・現在日の範囲・試合日ページ・この道具の S2b / S11。SeasonSchedule::GAME_DATE_TYPES。" \
    "試合数に数える日はこのうち真偽値 no_game が偽の日だけ）" => SeasonSchedule::GAME_DATE_TYPES
  }.freeze

  FIRST_SQUAD_MAX = 29 # team_rosters_controller#validate_first_squad_constraints と同じ
  COOLDOWN_DAYS = 10 # CooldownCalculable と同じ
  CHECK_GAME_DAY_TYPES = SeasonSchedule::GAME_DATE_TYPES
  S11_GAME_DAY_TYPES = SeasonSchedule::GAME_DATE_TYPES

  Roster = Struct.new(:id, :registered_on, :squad, :created_at, keyword_init: true)

  attr_reader :findings, :warnings, :elapsed, :reference

  # team_id: 指定すればそのチームだけ。recompute: false なら S8c（再計算。重い）を省く
  def initialize(team_id: nil, recompute: true)
    @team_id = team_id.presence&.to_i
    @recompute = recompute
    @findings = []
    @warnings = []
    @reference = {}
  end

  def call
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    load_data
    audit_s1
    audit_s2a
    audit_s2b
    audit_s2c
    audit_s7
    audit_s8a_s8b
    audit_s8c if @recompute
    audit_s9
    audit_s10
    audit_s11
    audit_s12
    @findings.sort_by! { |f| sort_key(f) }
    @elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    self
  end

  # 項目コード → { count:, teams:, players:, categories: { 分類 => 件数 } }
  def summary
    ITEMS.keys.index_with do |code|
      rows = @findings.select { |f| f.item == code }
      {
        count: rows.size,
        teams: rows.map(&:team_id).compact.uniq.size,
        players: rows.map(&:player_id).compact.uniq.size,
        categories: rows.group_by(&:category).transform_values(&:size).sort.to_h
      }
    end
  end

  def team_names
    @team_names ||= Team.where(id: @findings.map(&:team_id).compact.uniq).pluck(:id, :name).to_h
  end

  def player_names
    @player_names ||= Player.where(id: @findings.map(&:player_id).compact.uniq).pluck(:id, :name).to_h
  end

  private

  def sort_key(finding)
    [ finding.item, finding.team_id || 0, finding.date.to_s, finding.player_id || 0, finding.category.to_s, finding.ref || 0 ]
  end

  def add(item, category, team_id:, player_id: nil, date: nil, ref: nil, evidence: nil)
    @findings << Finding.new(item: item, category: category, team_id: team_id, player_id: player_id,
                             date: date&.to_s, ref: ref, evidence: evidence)
  end

  def load_data
    teams_scope = Team.all
    teams_scope = teams_scope.where(id: @team_id) if @team_id
    season_rows = Season.where(team_id: teams_scope.select(:id)).pluck(:team_id, :id, :current_date)
    # 現在日は日程の結果から導く（SeasonCurrentRange）。日程の無いシーズンだけ列の値
    ranges = SeasonCurrentRange.for_seasons(season_rows.map { |_, season_id, _| season_id })
    @season_by_team = season_rows.to_h { |team_id, season_id, current| [ team_id, { id: season_id, current_date: ranges[season_id]&.current_date || current } ] }
    @team_by_season = @season_by_team.to_h { |team_id, s| [ s[:id], team_id ] }

    memberships = TeamMembership.where(team_id: @season_by_team.keys).pluck(:id, :team_id, :player_id, :squad)
    @membership = memberships.to_h { |id, team_id, player_id, squad| [ id, { id: id, team_id: team_id, player_id: player_id, squad: squad } ] }
    @membership_by_key = @membership.values.to_h { |m| [ [ m[:team_id], m[:player_id] ], m ] }
    @members_by_team = @membership.values.group_by { |m| m[:team_id] }

    # 昇降格の変更記録を選手（team_membership）ごとに持つ。並びは (registered_on, created_at, id)。ロスター画面の求め方と同じ
    @rosters_in_insert_order = Hash.new { |h, k| h[k] = [] }
    SeasonRoster.where(team_membership_id: @membership.keys)
                .order(:id)
                .pluck(:id, :team_membership_id, :registered_on, :squad, :created_at).each do |id, tm_id, on, squad, created|
      @rosters_in_insert_order[tm_id] << Roster.new(id: id, registered_on: on, squad: squad, created_at: created)
    end
    @rosters = @rosters_in_insert_order.transform_values do |list|
      list.sort_by { |r| [ r.registered_on, r.created_at, r.id ] }
    end

    @schedules = SeasonSchedule.where(season_id: @team_by_season.keys)
                               .order(:season_id, :date, :id)
                               .pluck(:id, :season_id, :date, :date_type, :no_game)
                               .map { |id, season_id, date, type, flag| { id: id, team_id: @team_by_season[season_id], date: date, date_type: type, no_game: flag } }
    @schedule_by_team_date = @schedules.group_by { |s| [ s[:team_id], s[:date] ] }

    @pitcher_states = PitcherGameState.where(team_id: @season_by_team.keys)
                                      .order(:id)
                                      .pluck(:id, :team_id, :pitcher_id, :schedule_date, :role, :created_at, :season_schedule_id)
                                      .map do |id, team_id, pitcher_id, date_str, role, created, schedule_id|
      date = begin
        Date.iso8601(date_str.to_s)
      rescue ArgumentError
        nil
      end
      @warnings << "pitcher_game_states.id=#{id}: schedule_date を日付として読めない（#{date_str.inspect}）。S7・S8・S11 から除外" unless date
      { id: id, team_id: team_id, pitcher_id: pitcher_id, date: date, role: role, created_at: created, season_schedule_id: schedule_id }
    end.select { |s| s[:date] }

    @absences = PlayerAbsence.where(team_membership_id: @membership.keys)
                             .pluck(:id, :team_membership_id, :start_date, :phase, :absence_type, :duration, :duration_unit)
                             .map do |id, tm_id, start_date, phase, type, duration, unit|
      { id: id, team_id: @membership.dig(tm_id, :team_id), player_id: @membership.dig(tm_id, :player_id), start_date: start_date, phase: phase,
        absence_type: type, duration: duration, duration_unit: unit }
    end
  end

  # records（並べ替え済み）の date 時点の最後の記録。無ければ nil
  def record_at(records, date)
    return nil if records.blank?

    index = records.bsearch_index { |r| r.registered_on > date }
    return records.last if index.nil?
    return nil if index.zero?

    records[index - 1]
  end

  def next_record_after(records, date)
    return nil if records.blank?

    index = records.bsearch_index { |r| r.registered_on > date }
    index && records[index]
  end

  # --- S1 ---
  def audit_s1
    @membership.each_value do |m|
      records = @rosters[m[:id]]
      next if records.blank?

      latest = records.last
      next if latest.squad == m[:squad]

      current_date = @season_by_team.dig(m[:team_id], :current_date)
      at_current = current_date ? record_at(records, current_date)&.squad : nil
      category = at_current && at_current != m[:squad] ? "at_current_date" : "future_record_only"
      add("S1", category, team_id: m[:team_id], player_id: m[:player_id], date: latest.registered_on, ref: latest.id,
          evidence: "写し=#{m[:squad]} / 最後の記録=#{latest.squad}（#{latest.registered_on}）/ 現在日カーソル(#{current_date}) 時点=#{at_current || '記録なし'}")
    end
  end

  # --- S2a ---
  def audit_s2a
    @membership.each_value do |m|
      list = @rosters_in_insert_order[m[:id]]
      next if list.size < 2

      involved = {}
      list.each_with_index do |later, j|
        list.first(j).each do |earlier|
          next unless later.registered_on < earlier.registered_on

          involved[later.id] = [ later, "inserted_later", earlier ]
          involved[earlier.id] ||= [ earlier, "overtaken", later ]
        end
      end
      involved.each_value do |rec, category, other|
        evidence = category == "inserted_later" ? "先に作られた id=#{other.id}（#{other.registered_on}）より前の日付で後から差し込み" : "後から作られた id=#{other.id}（#{other.registered_on}）に日付で追い越された"
        add("S2a", category, team_id: m[:team_id], player_id: m[:player_id], date: rec.registered_on, ref: rec.id,
            evidence: "#{rec.squad}（作成順の #{list.index(rec) + 1} 件目）: #{evidence}")
      end
    end
  end

  # --- S2b ---
  def audit_s2b
    minimum = Team.first_squad_minimum_players
    @season_by_team.each_key do |team_id|
      members = @members_by_team[team_id] || []
      next if members.empty?

      record_dates = members.flat_map { |m| (@rosters[m[:id]] || []).map(&:registered_on) }
      next if record_dates.empty?

      schedule_dates = @schedules.select { |s| s[:team_id] == team_id }
      first_record_date = record_dates.min
      season_start = schedule_dates.map { |s| s[:date] }.min # 初日は最低人数の検査を免除する（コントローラと同じ）
      game_dates = schedule_dates.select { |s| CHECK_GAME_DAY_TYPES.include?(s[:date_type]) }.map { |s| s[:date] }.uniq

      (schedule_dates.map { |s| s[:date] } + record_dates).uniq.sort.each do |date|
        count = members.count { |m| record_at(@rosters[m[:id]], date)&.squad == "first" }
        types = (@schedule_by_team_date[[ team_id, date ]] || []).map { |s| s[:date_type] }.join(",")
        types = "日程なし" if types.empty?
        if count > FIRST_SQUAD_MAX
          add("S2b", "over_max", team_id: team_id, date: date, evidence: "1軍 #{count} 人（上限 #{FIRST_SQUAD_MAX}）種別=#{types}")
        elsif count < minimum && game_dates.include?(date) && date >= first_record_date && date != season_start
          add("S2b", "under_min", team_id: team_id, date: date, evidence: "1軍 #{count} 人（最低 #{minimum}）種別=#{types}")
        end
      end
    end
  end

  # --- S2c ---
  def audit_s2c
    @membership.each_value do |m|
      # 直前と同じ区分への記録（S3。状態が変わらない）は降格・昇格に数えない。連続する同じ区分は最初の 1 件だけ残す
      records = (@rosters[m[:id]] || []).each_with_object([]) { |r, kept| kept << r if kept.empty? || kept.last.squad != r.squad }

      records.each_with_index do |promo, i|
        next unless promo.squad == "first" && i.positive?

        demotion = records[i - 1] # 畳んだので直前は必ず 2軍の記録
        previous_promotion = records.first(i - 1).reverse.find { |r| r.squad == "first" }
        next unless previous_promotion

        cooldown_until = demotion.registered_on + COOLDOWN_DAYS
        next unless promo.registered_on < cooldown_until
        next if previous_promotion.registered_on == demotion.registered_on

        add("S2c", "cooldown", team_id: m[:team_id], player_id: m[:player_id], date: promo.registered_on, ref: promo.id,
            evidence: "降格 #{demotion.registered_on}（id=#{demotion.id}）→ 昇格 #{promo.registered_on}。再登録不可は #{cooldown_until} の前日まで")
      end
    end
  end

  # --- S7 ---
  def audit_s7
    @pitcher_states.each do |state|
      m = @membership_by_key[[ state[:team_id], state[:pitcher_id] ]]
      unless m
        add("S7", "no_membership", team_id: state[:team_id], player_id: state[:pitcher_id], date: state[:date], ref: state[:id],
            evidence: "チームの在籍(team_memberships)が無い")
        next
      end

      records = @rosters[m[:id]]
      at = record_at(records, state[:date])
      next if at&.squad == "first"

      following = next_record_after(records, state[:date])
      reason = if at && at.registered_on == state[:date]
        "same_day_demoted"
      elsif following && following.squad == "first" && following.registered_on == state[:date] + 1
        "promoted_next_day"
      else
        "other"
      end
      state_label = at ? "second" : "unregistered"
      evidence = at ? "直前の記録 #{at.squad}（#{at.registered_on}）" : "試合日以前に昇降格の記録なし"
      evidence += " / 次の記録 #{following.squad}（#{following.registered_on}）" if following
      add("S7", "#{state_label}/#{reason}", team_id: state[:team_id], player_id: state[:pitcher_id], date: state[:date], ref: state[:id], evidence: evidence)
    end
  end

  # --- S8a・S8b ---
  def audit_s8a_s8b
    entry_key = ->(s) { [ s[:created_at], s[:id] ] }

    @pitcher_states.group_by { |s| s[:team_id] }.each do |team_id, states|
      groups = states.group_by { |s| s[:date] }.map { |date, rows| [ date, rows.map(&entry_key).min, rows.size ] }
      later_min = nil # より後の日付の束の最初の入力のうち最小
      groups.sort_by { |g| g[0] }.reverse_each do |date, key, size|
        if later_min && (later_min[1] <=> key) == -1
          add("S8a", "late_entered", team_id: team_id, date: date, evidence: "登板 #{size} 件。より後の日付 #{later_min[0]} の登板が先に入力済み")
        end
        later_min = [ date, key ] if later_min.nil? || (key <=> later_min[1]) == -1
      end
    end

    @pitcher_states.group_by { |s| [ s[:team_id], s[:pitcher_id] ] }.each do |(team_id, pitcher_id), states|
      later_min = nil
      states.sort_by { |s| [ s[:date], s[:id] ] }.reverse_each do |s|
        key = entry_key.call(s)
        if later_min && (later_min[1] <=> key) == -1
          add("S8b", s[:role], team_id: team_id, player_id: pitcher_id, date: s[:date], ref: s[:id],
              evidence: "より後の日付 #{later_min[0]}（id=#{later_min[2]}）の登板が先に入力済み")
        end
        later_min = [ s[:date], key, s[:id] ] if later_min.nil? || (key <=> later_min[1]) == -1
      end
    end
  end

  # --- S8c ---
  def audit_s8c
    rebuilder = PitcherHistoryRebuild.from(team_id: @team_id, apply: false)
    rebuilder.rows.each do |r|
      category = if r.status == :changed then "changed"
      elsif r.status == :fatigue_only then "fatigue_only"
      elsif r.consecutive_changed? then "consecutive_only"
      end
      next unless category

      add("S8c", category, team_id: r.team_id, player_id: r.pitcher_id, date: r.schedule_date, ref: r.state_id,
          evidence: "区分 #{r.old_category}→#{r.new_category} / 疲労P #{r.old_fatigue_p}→#{r.new_fatigue_p} / 連続中4日 #{r.old_consecutive_short_rest_count}→#{r.new_consecutive_short_rest_count}")
    end
  end

  # --- S9 ---
  def audit_s9
    appearance_dates = @pitcher_states.group_by { |st| [ st[:team_id], st[:pitcher_id] ] }.transform_values { |list| list.map { |st| st[:date] }.to_set }
    same_day = @absences.select { |a| appearance_dates[[ a[:team_id], a[:player_id] ]]&.include?(a[:start_date]) }
    same_day.select { |a| a[:phase] == "pre_game" }.each do |a|
      add("S9", a[:absence_type], team_id: a[:team_id], player_id: a[:player_id], date: a[:start_date], ref: a[:id],
          evidence: "離脱 #{a[:absence_type]} #{a[:duration]}#{a[:duration_unit] == 'games' ? '試合' : '日'}（区分 pre_game）の開始日 #{a[:start_date]} に登板がある。試合中の負傷なら区分を in_game に直す")
    end
    @reference["S9"] = {
      "開始日が登板日と同じ離脱（pre_game・数えた件数）" => same_day.count { |a| a[:phase] == "pre_game" },
      "開始日が登板日と同じ離脱（in_game・正常）" => same_day.count { |a| a[:phase] == "in_game" }
    }
  end

  # --- S10 ---
  def audit_s10
    pitcher_count_by_day = @pitcher_states.group_by { |s| [ s[:team_id], s[:date] ] }.transform_values(&:size)
    @schedules.each do |s|
      next unless s[:date_type] == SeasonSchedule::NO_GAME_DATE_TYPE

      category = s[:no_game] ? "type_no_game_flag_true" : "type_no_game_flag_false"
      add("S10", category, team_id: s[:team_id], date: s[:date], ref: s[:id],
          evidence: "種別=#{s[:date_type]} / no_game=#{s[:no_game]} / その日の登板 #{pitcher_count_by_day[[ s[:team_id], s[:date] ]] || 0} 件")
    end
    @reference["S10"] = {
      "種別 no_game の日数" => @schedules.count { |s| s[:date_type] == "no_game" },
      "真偽値 no_game が真の日数" => @schedules.count { |s| s[:no_game] },
      "真偽値 no_game が真で種別が試合日でない日数（予備日などのまま）" => @schedules.count { |s| s[:no_game] && !SeasonSchedule::GAME_DATE_TYPES.include?(s[:date_type]) },
      "種別 no_game の日の登板件数" => @schedules.select { |s| s[:date_type] == "no_game" }.sum { |s| pitcher_count_by_day[[ s[:team_id], s[:date] ]] || 0 }
    }
  end

  # --- S11 ---
  def audit_s11
    @pitcher_states.each do |state|
      schedules = @schedule_by_team_date[[ state[:team_id], state[:date] ]]
      types = schedules ? schedules.map { |s| s[:date_type] } : []
      next if types.any? { |t| S11_GAME_DAY_TYPES.include?(t) }

      category = types.empty? ? "no_schedule" : types.uniq.join(",")
      add("S11", category, team_id: state[:team_id], player_id: state[:pitcher_id], date: state[:date], ref: state[:id],
          evidence: "日程の種別=#{types.empty? ? 'なし' : types.join(',')}")
    end
    @reference["S11"] = @schedules.group_by { |s| s[:date_type] }.transform_values(&:size).sort.to_h
  end

  # --- S12 ---
  def audit_s12
    @pitcher_states.each do |state|
      ids = (@schedule_by_team_date[[ state[:team_id], state[:date] ]] || []).map { |sc| sc[:id] }
      current = state[:season_schedule_id]
      category = if ids.empty? then current ? "mismatch" : "unlinked/no_schedule"
      elsif ids.size > 1 then current ? (ids.include?(current) ? nil : "mismatch") : "unlinked/ambiguous"
      elsif current.nil? then "unlinked/linkable"
      elsif current != ids.first then "mismatch"
      end
      next unless category

      evidence = "日程の行 #{ids.empty? ? 'なし' : ids.join(',')} / 登板の season_schedule_id=#{current.inspect}"
      add("S12", category, team_id: state[:team_id], player_id: state[:pitcher_id], date: state[:date], ref: state[:id], evidence: evidence)
    end
    @reference["S12"] = {
      "登板" => @pitcher_states.size,
      "紐づいている登板" => @pitcher_states.count { |st| st[:season_schedule_id] }
    }
  end
end
