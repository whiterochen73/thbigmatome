# 投手休養（試合間）の判定表と離脱日数の計算。
# PitcherGameStatesController（休養表示）と PitcherStarterFatigue（先発の試合前疲労P）が
# 同じ表を使うための共有モジュール。ルール: rulebook 08-pitcher-management.md §8.3.1 / §8.6
module PitcherRestStatus
  module_function

  # 先発→先発の補正表（§8.3.1）。キー: 前登板の result_category → 中日数 → 補正
  #   [:set, n]   疲労P を n に置き換える（中3日の P0）
  #   [:minus, n] カード疲労P から n を引く（下限 0）
  # 中日数が表に無い（カード値に戻る）場合は補正なし。
  # calculate_projected_status（休養表示）と同じ表であることは spec で突き合わせる。
  STARTER_REST_TABLE = {
    "normal" => { 3 => [ :set, 0 ], 4 => [ :minus, 3 ], 5 => [ :minus, 1 ] },
    "ko" => { 3 => [ :minus, 3 ] },
    "no_game" => { 3 => [ :minus, 3 ] },
    "long_loss" => { 3 => [ :set, 0 ], 4 => [ :minus, 4 ], 5 => [ :minus, 2 ], 6 => [ :minus, 1 ] }
  }.freeze

  # リリーフ→先発のスラッシュ選手（§8.3.4）。キー: 直近リリーフ登板直後の累積イニング区分 → 中日数 → 補正
  #   通常選手は STARTER_REST_TABLE["normal"] と同じ表（§8.3.4 通常選手）
  SLASH_AFTER_RELIEF_TABLE = {
    2 => { 3 => [ :minus, 1 ] },                                  # 累積2I以下
    3 => { 3 => [ :minus, 3 ], 4 => [ :minus, 1 ] },              # 累積3I
    4 => { 3 => [ :set, 0 ], 4 => [ :minus, 3 ], 5 => [ :minus, 1 ] } # 累積4I以上
  }.freeze

  # 先発の登板可否の下限。中2日以内は登板不可。
  MAX_UNAVAILABLE_REST_DAYS = 2

  # 中10日リセット（疲労P をカード値へ・累積イニング 0）の実日数差。離脱期間は関与しない（AMB-04 追補）。
  RESET_REST_DAYS = 10

  # 先発の試合前疲労P（補正後）を返す。登板不可の中日数では nil。
  def starter_fatigue_p(card_fatigue_p, result_category, rest_days)
    return nil if rest_days <= MAX_UNAVAILABLE_REST_DAYS

    rule = STARTER_REST_TABLE.fetch(result_category || "normal", STARTER_REST_TABLE["normal"])[rest_days]
    apply_rule(card_fatigue_p, rule)
  end

  # 前回がリリーフ/オープナーだったスラッシュ選手が先発する時の試合前疲労P（§8.3.4）。
  # cumulative_innings: 直近リリーフ登板の累積イニング（その登板を加算した直後の値）
  def slash_starter_fatigue_p_after_relief(card_fatigue_p, cumulative_innings, rest_days)
    return nil if rest_days <= MAX_UNAVAILABLE_REST_DAYS

    bucket = [ [ cumulative_innings.to_i, 2 ].max, 4 ].min
    apply_rule(card_fatigue_p, SLASH_AFTER_RELIEF_TABLE.fetch(bucket)[rest_days])
  end

  def apply_rule(card_fatigue_p, rule)
    return card_fatigue_p if rule.nil?

    kind, n = rule
    kind == :set ? n : [ card_fatigue_p - n, 0 ].max
  end

  # [from_date, to_date] (両端含む) 内の離脱日数合計を返す
  # end_date は排他的（復帰可能日）
  def absence_days_in_range(absences, from_date, to_date)
    return 0 if absences.empty? || from_date > to_date
    absences.sum do |pa|
      i_start = [ pa[:start_date], from_date ].max
      i_end_excl = pa[:end_date] ? pa[:end_date] : to_date + 1
      i_end_clamped = [ i_end_excl, to_date + 1 ].min
      days = (i_end_clamped - i_start).to_i
      days > 0 ? days : 0
    end
  end

  # 実日数の中日数 (target - last) - 1。離脱を差し引かない。
  def raw_rest_days(last_date, target_date)
    (target_date - last_date).to_i - 1
  end

  # 中10日リセットの判定（AMB-04 追補 / rulebook §8.6 訂正 2026-09-13）。
  # 離脱の有無・長短にかかわらず、実日数差が中10日以上ならリセットする。
  # 離脱を差し引いた中日数（登板可否・累積イニングの減衰に使う）とは別の量なので、同じ変数で持ち回らない。
  def rest_reset?(last_date, target_date)
    raw_rest_days(last_date, target_date) >= RESET_REST_DAYS
  end

  # 中日数の控除・減衰凍結に使う離脱（負傷のみ）。出場停止・再調整は含めない（AMB-04「出場停止と負傷は別枠」2026-09-12）。
  # 出場可否の表示（build_injured_set）はここを通さない。全種別の離脱を見る。
  # 戻り値: { team_membership_id => [{start_date:, end_date:}, ...] }（離脱が無い id は [] で引ける）
  #   end_date は復帰可能日（排他的）。nil は無期限離脱。
  def injury_absences(team_membership_ids)
    result = Hash.new { |_hash, _key| [] }
    PlayerAbsence.injury.where(team_membership_id: team_membership_ids).each do |pa|
      result[pa.team_membership_id] += [ { start_date: pa.start_date.to_date, end_date: pa.effective_end_date&.to_date } ]
    end
    result
  end

  # projected_status: 今日登板した場合の疲労ステータス予測
  # 戻り値: "full" / "reduced_N" / "injury_check" / "unavailable" / "injured"
  def calculate_projected_status(last_role, rest_days, last_result_category, cumulative_innings, is_injured, consecutive_short_rest_count)
    return "injured" if is_injured
    return "full" if last_role.nil?

    if last_role == "starter"
      return "full" if rest_days.nil?
      return "unavailable" if rest_days <= 2

      cat = last_result_category || "normal"
      case cat
      when "ko", "no_game"
        case rest_days
        when 3 then "reduced_3"
        when 4 then consecutive_short_rest_count >= 1 ? "injury_check" : "full" # 2回連続の中4日で負傷チェック（§8.3.1）
        else "full"
        end
      when "long_loss"
        case rest_days
        when 3 then "injury_check"
        when 4 then consecutive_short_rest_count >= 1 ? "injury_check" : "reduced_4" # 同上

        when 5 then "reduced_2"
        when 6 then "reduced_1"
        else "full"
        end
      else # normal
        case rest_days
        when 3 then "injury_check"
        when 4
          consecutive_short_rest_count >= 1 ? "injury_check" : "reduced_3"
        when 5 then "reduced_1"
        else "full"
        end
      end
    else # reliever / opener
      reliever_status_after_reliever(cumulative_innings, rest_days)
    end
  end

  # ─── 投手ごとの「先発なら」「リリーフなら」（cmd_1775 第3段 E9・E10）────────────────────
  #
  # status の値（既存の値に 3 つ足した）:
  #   full / reduced_N / injury_check / unavailable / injured    … 既存
  #   fatigued_start        登板の最初から疲労状態（AMB-19 追補。疲労P0 とは別の状態）
  #   fatigued_start_check  最初から疲労状態 + 登板後の負傷チェック（累積3I 以上のリリーフ登板 §8.3.2・§8.5.1 条件3）
  #   no_rule               §8.3.3 の表に載っていない中日数（P0 になる日より短い）。ルールに規定が無いので推測しない
  # 注記（notes）:
  #   opener_injury_check                 オープナーとして登板するなら負傷チェック（累積1I 以上・§8.4.3）。リリーフなら側のみ
  #   previous_day_one_inning_only        累積4I 以上で前日登板: 前日の負傷チェックに合格していれば 1 イニング限定で登板可（§8.3.2）。
  #                                       合否は記録しないので、画面に注意書きだけ出す（Operator 決定 2026-10-26）

  # 先発→リリーフ（§8.3.3）。キー: 前登板の result_category → [P0 になる中日数, カード値に戻る中日数]
  RELIEVER_AFTER_STARTER_TABLE = {
    "normal" => [ 3, 4 ],
    "ko" => [ 2, 3 ],
    "no_game" => [ 2, 3 ],
    "long_loss" => [ 4, 5 ]
  }.freeze

  # スラッシュ選手（先発もリリーフもできるカード）は先発→リリーフが各ケース 1 日短い（§8.3.3）
  SLASH_RELIEVER_SHORTENING_DAYS = 1

  # リリーフの中日数による回復の上限（AMB-21）。中5日 → 累積1以下（P0）、中6日以上 → 累積0（カード値）
  RELIEVER_RECOVERY_CAP = { 5 => 1 }.freeze
  RELIEVER_FULL_RECOVERY_DAYS = 6

  # 累積3I 以上で登板すると試合後に負傷チェック（§8.3.2・§8.5.1 条件3）
  RELIEVER_INJURY_CHECK_CUMULATIVE = 3
  # 累積4I 以上で前日登板した時の制限（§8.3.2）
  PREVIOUS_DAY_LIMIT_CUMULATIVE = 4

  # 休養日数による回復の上限を掛けた累積。累積の減衰でそれより良ければそのまま（中5日で P0 に悪化させない）。
  # rest_days は負傷控除後の値（nil は登板歴なし）。
  def capped_reliever_cumulative(cumulative_innings, rest_days)
    return cumulative_innings if rest_days.nil?
    return 0 if rest_days >= RELIEVER_FULL_RECOVERY_DAYS

    cap = RELIEVER_RECOVERY_CAP[rest_days]
    cap ? [ cumulative_innings, cap ].min : cumulative_innings
  end

  # リリーフ→リリーフ（§8.3.2）の登板時の状態
  def reliever_status_after_reliever(cumulative_innings, rest_days)
    case capped_reliever_cumulative(cumulative_innings, rest_days)
    when 0 then "full"
    when 1 then "reduced_0"
    when 2 then "fatigued_start"
    else "fatigued_start_check"
    end
  end

  # 先発→リリーフ（§8.3.3）の登板時の状態
  def reliever_status_after_starter(result_category, rest_days, slash)
    zero_day, card_day = RELIEVER_AFTER_STARTER_TABLE.fetch(result_category || "normal", RELIEVER_AFTER_STARTER_TABLE["normal"])
    if slash
      zero_day -= SLASH_RELIEVER_SHORTENING_DAYS
      card_day -= SLASH_RELIEVER_SHORTENING_DAYS
    end
    if rest_days >= card_day then "full"
    elsif rest_days == zero_day then "reduced_0"
    else "no_rule"
    end
  end

  # リリーフ/オープナー→先発（§8.3.4）の登板時の状態。中2日以内は先発不可（§8.7.2）。
  # relief_cumulative: 直近リリーフ登板直後の累積（減衰前）。スラッシュ選手の表選びに使う（AMB-18 追補）
  def starter_status_after_reliever(rest_days, slash, relief_cumulative)
    return "unavailable" if rest_days <= MAX_UNAVAILABLE_REST_DAYS

    rule = if slash
      bucket = [ [ relief_cumulative.to_i, 2 ].max, 4 ].min
      SLASH_AFTER_RELIEF_TABLE.fetch(bucket)[rest_days]
    else
      STARTER_REST_TABLE["normal"][rest_days]
    end
    status_from_rule(rule)
  end

  # 補正ルール → 状態。P0 に置き換える中3日は負傷チェック（§8.5.1 条件1）
  def status_from_rule(rule)
    return "full" if rule.nil?

    kind, n = rule
    return "injury_check" if kind == :set && n.zero?

    "reduced_#{n}"
  end

  # 登板時の状態を「先発なら」「リリーフなら」で並べて返す。表示の省略（リリーフ専門の「先発なら」など）は呼び出し側で行う。
  #
  # 引数:
  #   last_role / rest_days（負傷控除後。リセット成立時は差し引かない実日数）/ raw_rest_days（実日数差）/
  #   reset（実日数差で中10日リセット成立）/ last_result_category（前回登板の区分）/
  #   cumulative_innings（対象日時点の累積・減衰後）/ relief_cumulative_after_last（直近リリーフ登板直後の累積）/
  #   consecutive_short_rest_count（直近の登板に保存された連続中4日の回数）/ is_injured / slash
  # 戻り値: { as_starter: { status:, notes: [] }, as_reliever: { status:, notes: [] } }
  def role_states(last_role:, rest_days:, raw_rest_days:, reset:, last_result_category:, cumulative_innings:,
                  relief_cumulative_after_last:, consecutive_short_rest_count:, is_injured:, slash:)
    return both_states("injured") if is_injured
    # 中10日リセットは前回の役割・中日数に依らず最優先（AMB-04 追補 2）。累積は 0、疲労P はカード値
    return both_states("full") if last_role.nil? || reset || rest_days.nil?

    if last_role == "starter"
      as_starter = calculate_projected_status("starter", rest_days, last_result_category, 0, false, consecutive_short_rest_count)
      as_reliever = reliever_status_after_starter(last_result_category, rest_days, slash)
      reliever_notes = []
    else
      as_starter = starter_status_after_reliever(rest_days, slash, relief_cumulative_after_last)
      as_reliever = reliever_status_after_reliever(cumulative_innings, rest_days)
      reliever_notes = reliever_notes_after_reliever(cumulative_innings, rest_days, raw_rest_days)
    end

    { as_starter: { status: as_starter, notes: [] }, as_reliever: { status: as_reliever, notes: reliever_notes } }
  end

  def both_states(status)
    { as_starter: { status: status, notes: [] }, as_reliever: { status: status, notes: [] } }
  end

  # リリーフなら側の注記。上限を掛けた後の累積で決める。前日登板は離脱を差し引かない実日数で見る
  def reliever_notes_after_reliever(cumulative_innings, rest_days, raw_rest_days)
    effective = capped_reliever_cumulative(cumulative_innings, rest_days)
    notes = []
    notes << "opener_injury_check" if effective >= 1
    notes << "previous_day_one_inning_only" if effective >= PREVIOUS_DAY_LIMIT_CUMULATIVE && raw_rest_days == 0
    notes
  end

  # 指定日時点のリリーフ/オープナーの累積イニング（減衰込み）。離脱中は減衰凍結（absences は負傷のみを渡す）。
  # 実日数差が中10日以上ならリセット（離脱の有無は関与しない）。
  # PitcherGameStatesController（休養表示）と PitcherStarterFatigue（リリーフ→先発の補正）で共有する。
  def cumulative_innings(team_id, pitcher_id, target_date, absences = [])
    appearances = PitcherGameState
      .where(pitcher_id: pitcher_id, team_id: team_id, role: %w[reliever opener])
      .where("schedule_date < ?", target_date.to_s)
      .order(schedule_date: :asc)

    cumulative = 0
    prev_date = nil

    appearances.each do |app|
      if prev_date
        app_date = app.schedule_date.to_date
        if rest_reset?(prev_date, app_date)
          # 実日数中10日以上 → 全快（累積リセット）
          cumulative = 0
        else
          from = prev_date + 1
          to = app_date - 1
          idle_days = (app_date - prev_date).to_i - 1
          absent_days = absence_days_in_range(absences, from, to)
          effective_idle = [ idle_days - absent_days, 0 ].max
          effective_idle.times do
            cumulative = cumulative <= 3 ? [ cumulative - 2, 0 ].max : cumulative - 1
          end
        end
      end
      prior_outs = PitcherGameState
        .where(game_id: app.game_id, team_id: app.team_id)
        .where("appearance_order < ?", app.appearance_order)
        .pluck(:innings_pitched)
        .sum { |s| PitcherInnings.outs_from_innings(s) }
      involvement = PitcherInnings.involvement(app.innings_pitched, prior_outs: prior_outs, no_out_exit: app.no_out_exit)
      cumulative += [ involvement, 1 ].max
      prev_date = app.schedule_date.to_date
    end

    # Decay from last appearance to target_date
    if prev_date && prev_date < target_date
      if rest_reset?(prev_date, target_date)
        cumulative = 0
      else
        from = prev_date + 1
        to = target_date - 1
        idle_days = (target_date - prev_date).to_i - 1
        absent_days = absence_days_in_range(absences, from, to)
        effective_idle = [ idle_days - absent_days, 0 ].max
        effective_idle.times do
          cumulative = cumulative <= 3 ? [ cumulative - 2, 0 ].max : cumulative - 1
        end
      end
    end

    [ cumulative, 0 ].max
  end
end
