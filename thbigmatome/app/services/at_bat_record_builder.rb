class AtBatRecordBuilder
  # クラスメソッド: コントローラーから直接呼び出し可能
  def self.build_source_events(ab_params)
    new.build_source_events(ab_params)
  end

  def self.normalize_discrepancies(raw_discrepancies)
    new.normalize_discrepancies(raw_discrepancies)
  end

  # パーサー出力の各フィールドからsource_eventsを構築する
  # 宣言(declaration) / ダイス(dice) / 自動計算(auto) の3分類
  def build_source_events(ab_params)
    raw = ab_params.respond_to?(:to_unsafe_h) ? ab_params.to_unsafe_h : ab_params.to_h
    raw = raw.with_indifferent_access

    events = []
    seq = 0

    # 1. 宣言: eventsフィールド（投手交代/代打/代走等）
    Array(raw[:events]).each do |ev|
      type = (ev[:type] || ev["type"] || ev[:event_type] || ev["event_type"]).to_s
      next if type.blank?
      seq += 1
      entry = { seq: seq, type: "declaration", subtype: type }
      entry[:speaker] = ev[:speaker] if ev[:speaker].present?
      entry[:text] = ev[:text] if ev[:text].present?
      events << entry
    end

    # 2. 宣言: strategy（エンドラン/バント/故意四球/盗塁）
    strategy = raw[:strategy].to_s
    if %w[endrun bunt bunt_fc intentional_walk steal].include?(strategy)
      seq += 1
      events << { seq: seq, type: "declaration", subtype: strategy }
    end

    # 3. 宣言: 内野/外野前進守備
    infield = raw[:infield_forward].present? && raw[:infield_forward] != false && raw[:infield_forward] != "false"
    outfield = raw[:outfield_forward].present? && raw[:outfield_forward] != false && raw[:outfield_forward] != "false"
    if infield && outfield
      seq += 1
      events << { seq: seq, type: "declaration", subtype: "infield_outfield_forward" }
    elsif infield
      seq += 1
      events << { seq: seq, type: "declaration", subtype: "infield_forward" }
    elsif outfield
      seq += 1
      events << { seq: seq, type: "declaration", subtype: "outfield_forward" }
    end

    # 4. ダイス: 盗塁（st/ed判定）— 打席前に発生
    Array(raw[:steal_attempts]).each do |steal|
      base = steal[:base]
      st_dice = steal[:st_dice]
      if st_dice
        seq += 1
        events << { seq: seq, type: "dice", subtype: "steal_st",
                    roll: st_dice.to_i, base: base, result: steal[:st_result].to_s }
      end
      ed_dice = steal[:ed_dice]
      if ed_dice
        seq += 1
        events << { seq: seq, type: "dice", subtype: "steal_ed",
                    roll: ed_dice.to_i, base: base, result: steal[:ed_result].to_s }
      end
    end

    # 5. ダイス: 投球
    pitch_roll = raw[:pitch_roll]
    if pitch_roll.present?
      seq += 1
      events << { seq: seq, type: "dice", subtype: "pitch",
                  roll: pitch_roll.to_i, result: raw[:pitch_result].to_s }
    end

    # 6. ダイス: 打撃
    bat_roll = raw[:bat_roll]
    if bat_roll.present?
      seq += 1
      events << { seq: seq, type: "dice", subtype: "bat",
                  roll: bat_roll.to_i, result: raw[:bat_result].to_s }
    end

    # 7. ダイス: extra_rolls（レンジチェック/エラーチェック/UP表/肩チェック等）
    Array(raw[:extra_rolls]).each do |roll|
      roll_val = roll[:roll]
      result = roll[:result].to_s
      event_type = roll[:event_type].to_s
      dice_list = roll[:dice_list]

      subtype = case event_type
      when "range_check" then "range_check"
      when "error_check" then "error_check"
      when "up_table"    then "up_table"
      when "shoulder_check" then "shoulder_check"
      when "bunt"        then "bunt_roll"
      else "extra"
      end

      entry = { seq: (seq += 1), type: "dice", subtype: subtype,
                roll: roll_val, result: result }
      entry[:dice_list] = dice_list if dice_list.present?
      entry[:event_type] = event_type if subtype == "extra" && event_type.present?
      events << entry.compact
    end

    # 8. 自動計算: 走者進塁
    runners_before = Array(raw[:runners_before]).map(&:to_i).sort
    runners_after  = Array(raw[:runners_after]).map(&:to_i).sort
    if runners_before != runners_after
      seq += 1
      events << { seq: seq, type: "auto", subtype: "runner_advance",
                  runners_before: runners_before, runners_after: runners_after }
    end

    # 9. 自動計算: 得点
    runs_scored = raw[:runs_scored].to_i
    if runs_scored > 0
      seq += 1
      events << { seq: seq, type: "auto", subtype: "scoring", runs: runs_scored }
    end

    # 10. 自動計算: アウトカウント変化
    outs_before = raw[:outs_before]
    outs_after  = raw[:outs_after]
    if outs_before.present? && outs_after.present? && outs_before.to_i != outs_after.to_i
      seq += 1
      events << { seq: seq, type: "auto", subtype: "out_recorded",
                  outs_before: outs_before.to_i, outs_after: outs_after.to_i }
    end

    events
  end

  # パーサー出力形式 { field, text, gsm } → DB格納形式 { field, text_value, gsm_value, cause, resolution } に変換
  def normalize_discrepancies(raw_discrepancies)
    Array(raw_discrepancies).map do |d|
      {
        "field" => d[:field] || d["field"],
        "text_value" => d[:text] || d["text"],
        "gsm_value" => d[:gsm] || d["gsm"],
        "cause" => d[:cause] || d["cause"] || "unknown",
        "resolution" => d[:resolution] || d["resolution"],
        "note" => d[:note] || d["note"]
      }.compact
    end
  end
end
