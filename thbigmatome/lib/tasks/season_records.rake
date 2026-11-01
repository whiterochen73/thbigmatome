require "csv"

namespace :season_records do
  desc <<~DESC
    シーズン記録の食い違いを数えて一覧にする（読むだけ。DB へは一切書かない）。cmd_1784 段0。
    設計書 context/thbig-dugout-season-record-restructure-design.md §1.3 の S1・S2・S7・S8・S9・S10・S11・S12 を数える。
    各段の移行の前後で同じ道具を回し、件数と明細を突き合わせる。
      bundle exec rake season_records:audit                       # 件数の要約を標準出力へ
      OUT=/path/to/audit.csv bundle exec rake season_records:audit # 明細 CSV もファイルへ
      TEAM_ID=3 bundle exec rake season_records:audit             # チームを絞る
      SKIP_RECOMPUTE=1 bundle exec rake season_records:audit      # S8c（先発の保存値の再計算。重い）を省く
    明細 CSV は item, category, team_id, team, player_id, player, date, ref, evidence の列で、
    item・team_id・date・player_id の順に並ぶ（移行前後で diff しやすい）。
  DESC
  task audit: :environment do
    audit = SeasonRecordAudit.new(team_id: ENV["TEAM_ID"], recompute: ENV["SKIP_RECOMPUTE"] != "1").call
    summary = audit.summary

    puts "# season_records:audit（読むだけ。DB は書かない）"
    puts "# 対象: #{ENV['TEAM_ID'].present? ? "チーム #{ENV['TEAM_ID']}" : '全チーム'} / S8c 再計算: #{ENV['SKIP_RECOMPUTE'] == '1' ? '省略' : 'あり'}"
    puts "#"
    puts "# --- 件数（項目: 定義） ---"
    SeasonRecordAudit::ITEMS.each do |code, (title, definition)|
      next if code == "S8c" && ENV["SKIP_RECOMPUTE"] == "1"

      s = summary.fetch(code)
      puts "#{code} #{title}: #{s[:count]} 件（チーム #{s[:teams]} / 選手 #{s[:players]}）"
      s[:categories].each { |category, n| puts "    #{category}: #{n}" }
      puts "    定義: #{definition}"
    end
    puts "#"
    puts "# --- 参考 ---"
    audit.reference.each do |code, values|
      puts "#{code}: #{values.map { |k, v| "#{k}=#{v}" }.join(' / ')}"
    end
    puts "試合日とみなす種別（S11。サーバの定義は 1 つ）:"
    SeasonRecordAudit::GAME_DAY_SETS.each { |where, types| puts "    #{where}: #{types.join(', ')}" }
    audit.warnings.each { |w| puts "# WARN: #{w}" }

    if ENV["OUT"].present?
      team_names = audit.team_names
      player_names = audit.player_names
      csv = CSV.generate do |out|
        out << %w[item category team_id team player_id player date ref evidence]
        audit.findings.each do |f|
          out << [ f.item, f.category, f.team_id, team_names[f.team_id], f.player_id, player_names[f.player_id], f.date, f.ref, f.evidence ]
        end
      end
      File.write(ENV["OUT"], csv)
      puts "# CSV written: #{ENV['OUT']}（#{audit.findings.size} 行）"
    end
    puts "# elapsed: #{format('%.1f', audit.elapsed)} 秒"
  end
  desc <<~DESC
    team_memberships.squad の写しを、昇降格の変更記録（season_rosters）の最新の状態から作り直す。cmd_1784 段1。
    変更記録の最新 = 記録を (registered_on, 区分, created_at, id) 順に並べ、直前と同じ区分への記録を畳んだ最後の squad。記録が無い選手は second。
    既定は試運転（DB を書かない）。APPLY=1 の時だけ書く。
      bundle exec rake season_records:rebuild_squad_cache                 # 試運転（差分の件数を標準出力へ）
      OUT=/path/to/diff.csv bundle exec rake season_records:rebuild_squad_cache  # 差分 CSV もファイルへ（変更前の値を残す。逆向きに当てられる）
      TEAM_ID=3 bundle exec rake season_records:rebuild_squad_cache       # チームを絞る
      APPLY=1 bundle exec rake season_records:rebuild_squad_cache         # 実際に書く
    差分 CSV は team_id, team, team_membership_id, player_id, player, old_squad, new_squad, last_record_id, last_record_date, last_record_phase,
    records の列。last_record_id が空の行は記録が無い選手（記録が無ければ second と読むので、写しが first なら second へ変わる）。
  DESC
  task rebuild_squad_cache: :environment do
    apply = ENV["APPLY"] == "1"
    teams = Team.order(:id)
    teams = teams.where(id: ENV["TEAM_ID"]) if ENV["TEAM_ID"].present?

    rows = []
    totals = Hash.new(0)
    ActiveRecord::Base.transaction do
      teams.find_each do |team|
        state = RosterState.new(team, memberships: team.all_team_memberships.preload(:season_rosters, :player).to_a)
        latest = state.latest_squads
        state.memberships.each do |tm|
          totals[:memberships] += 1
          next if tm.squad == latest[tm.id]

          last = state.collapsed_records(tm.id).last
          rows << [ team.id, team.name, tm.id, tm.player_id, tm.player&.name, tm.squad, latest[tm.id], last&.id, last&.registered_on, last&.phase,
                    tm.season_rosters.size ]
          totals[:no_record_first] += 1 if last.nil? && tm.squad == "first"
          totals["#{tm.squad}_to_#{latest[tm.id]}".to_sym] += 1
        end
        state.rebuild_squad_cache! if apply
      end
    end

    csv = CSV.generate do |out|
      out << %w[team_id team team_membership_id player_id player old_squad new_squad last_record_id last_record_date last_record_phase records]
      rows.each { |row| out << row }
    end
    if ENV["OUT"].present?
      File.write(ENV["OUT"], csv)
      puts "# CSV written: #{ENV['OUT']}（#{rows.size} 行）"
    else
      puts csv
    end
    puts "# mode: #{apply ? 'APPLY (DB updated)' : 'DRY-RUN (DB unchanged)'}"
    puts "# 対象: #{ENV['TEAM_ID'].present? ? "チーム #{ENV['TEAM_ID']}" : '全チーム'} / team_memberships #{totals[:memberships]} 件"
    puts "# 写しが変わる: #{rows.size} 件（チーム #{rows.map(&:first).uniq.size} / 選手 #{rows.map { |r| r[3] }.uniq.size}）"
    puts "#   first→second: #{totals[:first_to_second]} / second→first: #{totals[:second_to_first]}"
    puts "#   記録が無いのに写しが first（second へ変わる）: #{totals[:no_record_first]}"
  end

  desc <<~DESC
    チーム編成の変更記録（team_membership_changes）の初期記録を、既存の team_memberships から作る。cmd_1784 段2。
    選手（team_memberships の行）ごとに join を 1 件。日付は最初の昇降格の日とシーズン開始日（日程の最初の日）の早い方、区分は pre_game、
    値は移行時点の契約・カード・コスト除外・表示名。昇降格の記録もシーズン開始日もなければ現在日カーソルの日付。
    移行前の契約変更・放出は記録が無く復元できない（移行前の日付の検査は今の契約で行う。設計書 §5.2 段2）。
    すでに記録がある行・シーズンの無いチームの行は作らない（何度流しても同じ結果。シーズンの無いチームは記録が無い行を今の値で読む）。
    既定は試運転（DB を書かない）。APPLY=1 の時だけ書く。
      bundle exec rake season_records:backfill_membership_changes                 # 試運転（作る件数を標準出力へ）
      OUT=/path/to/backfill.csv bundle exec rake season_records:backfill_membership_changes  # 作る記録の CSV もファイルへ
      TEAM_ID=3 bundle exec rake season_records:backfill_membership_changes       # チームを絞る
      APPLY=1 bundle exec rake season_records:backfill_membership_changes         # 実際に書く
    CSV は team_id, team, team_membership_id, player_id, player, effective_on, phase, date_source（first_roster / season_start / current_date）、
    first_roster_date, season_start, selected_cost_type, player_card_id, excluded_from_team_total, display_name の列。
    戻す時は、この rake が作った記録（recorded_by_user_id が空の join）だけを消せば移行前に戻る（列と表は残してよい）。
  DESC
  task backfill_membership_changes: :environment do
    apply = ENV["APPLY"] == "1"
    teams = Team.order(:id)
    teams = teams.where(id: ENV["TEAM_ID"]) if ENV["TEAM_ID"].present?

    rows = []
    totals = Hash.new(0)
    by_source = Hash.new(0)
    ActiveRecord::Base.transaction do
      teams.find_each do |team|
        memberships = team.all_team_memberships.preload(:season_rosters, :team_membership_changes, :player).to_a
        season = team.season
        unless season
          totals[:no_season] += memberships.size
          next
        end

        season_start = season.season_schedules.minimum(:date)
        memberships.each do |tm|
          totals[:memberships] += 1
          if tm.team_membership_changes.any?
            totals[:already] += 1
            next
          end

          first_roster = tm.season_rosters.map(&:registered_on).min
          joined_on = TeamMembershipChange.initial_join_date(first_roster, season_start)
          source = if joined_on.nil? then "current_date"
          elsif first_roster && (season_start.nil? || first_roster < season_start) then "first_roster"
          else "season_start"
          end
          joined_on ||= season.current_date
          by_source[source] += 1
          totals[:later_first_roster] += 1 if first_roster && season_start && first_roster > season_start
          rows << [ team.id, team.name, tm.id, tm.player_id, tm.player&.name, joined_on, SeasonRoster::DEFAULT_PHASE, source, first_roster,
                    season_start, tm.selected_cost_type, tm.player_card_id, tm.excluded_from_team_total, tm.display_name ]
          next unless apply

          TeamMembershipChange.create!(
            team_membership: tm, season: season, kind: "join", effective_on: joined_on, phase: SeasonRoster::DEFAULT_PHASE,
            selected_cost_type: tm.selected_cost_type, player_card_id: tm.player_card_id,
            excluded_from_team_total: tm.excluded_from_team_total, display_name: tm.display_name
          )
        end
      end
    end

    csv = CSV.generate do |out|
      out << %w[team_id team team_membership_id player_id player effective_on phase date_source first_roster_date season_start
                selected_cost_type player_card_id excluded_from_team_total display_name]
      rows.each { |row| out << row }
    end
    if ENV["OUT"].present?
      File.write(ENV["OUT"], csv)
      puts "# CSV written: #{ENV['OUT']}（#{rows.size} 行）"
    else
      puts csv
    end
    puts "# mode: #{apply ? 'APPLY (DB updated)' : 'DRY-RUN (DB unchanged)'}"
    puts "# 対象: #{ENV['TEAM_ID'].present? ? "チーム #{ENV['TEAM_ID']}" : '全チーム'} / シーズンのあるチームの team_memberships #{totals[:memberships]} 件"
    puts "# 初期記録を作る: #{rows.size} 件（チーム #{rows.map(&:first).uniq.size} / 選手 #{rows.map { |r| r[3] }.uniq.size}）"
    puts "#   日付の出どころ: 最初の昇降格が開始日より前 #{by_source['first_roster']} / シーズン開始日 #{by_source['season_start']} / 現在日カーソル #{by_source['current_date']}"
    puts "#   （参考）最初の昇降格がシーズン開始日より後の選手: #{totals[:later_first_roster]} 件（開始日に登録したものとして読む）"
    puts "# 作らない: 記録あり #{totals[:already]} 件 / シーズンの無いチームの行 #{totals[:no_season]} 件"
  end

  desc <<~DESC
    登板（pitcher_game_states）の season_schedule_id を、（チーム, 試合日）から日程の行を引いて埋める。cmd_1784 段3。
    埋めるのは、紐づけが空で、そのチームのその日の日程の行がちょうど 1 件ある登板だけ。対応する日程の行が無い登板（no_schedule）・
    同じ日に複数ある登板（ambiguous）・日付が読めない登板（bad_date）・紐づけ先が引いた行と違う登板（mismatch）は、行を作らず・変えず、一覧に出す。
    既定は試運転（DB を書かない）。APPLY=1 の時だけ書く。何度流しても同じ結果になる。
      bundle exec rake season_records:link_pitcher_schedules                 # 試運転（件数と、紐づけられない登板の一覧を標準出力へ）
      OUT=/path/to/unlinkable.csv bundle exec rake season_records:link_pitcher_schedules  # 紐づけられない登板の CSV もファイルへ
      TEAM_ID=3 bundle exec rake season_records:link_pitcher_schedules       # チームを絞る
      APPLY=1 bundle exec rake season_records:link_pitcher_schedules         # 実際に書く
    CSV は team_id, team, pitcher_id, pitcher, schedule_date, state_id, status, schedule_ids, current_schedule_id の列。
    戻す時は pitcher_game_states.season_schedule_id を null にすればよい（列は残してよい。コードを戻せば schedule_date だけで読む）。
  DESC
  task link_pitcher_schedules: :environment do
    apply = ENV["APPLY"] == "1"
    linker = PitcherScheduleLinker.new(apply: apply, team_id: ENV["TEAM_ID"]).call
    summary = linker.summary
    unlinkable = linker.unlinkable

    team_names = Team.where(id: unlinkable.map(&:team_id).uniq).pluck(:id, :name).to_h
    pitcher_names = Player.where(id: unlinkable.map(&:pitcher_id).uniq).pluck(:id, :name).to_h
    csv = CSV.generate do |out|
      out << %w[team_id team pitcher_id pitcher schedule_date state_id status schedule_ids current_schedule_id]
      unlinkable.each do |r|
        out << [ r.team_id, team_names[r.team_id], r.pitcher_id, pitcher_names[r.pitcher_id], r.schedule_date, r.state_id, r.status,
                 r.schedule_ids.join(" "), r.current_schedule_id ]
      end
    end
    if ENV["OUT"].present?
      File.write(ENV["OUT"], csv)
      puts "# CSV written: #{ENV['OUT']}（#{unlinkable.size} 行）"
    else
      puts csv
    end
    puts "# mode: #{apply ? 'APPLY (DB updated)' : 'DRY-RUN (DB unchanged)'}"
    puts "# 対象: #{ENV['TEAM_ID'].present? ? "チーム #{ENV['TEAM_ID']}" : '全チーム'} / 登板 #{linker.rows.size} 件"
    puts "# 紐づける: #{summary.fetch(:linked, 0)} / すでに紐づいている: #{summary.fetch(:already, 0)}"
    puts "# 紐づけない（一覧に出す）: 対応する日程の行が無い #{summary.fetch(:no_schedule, 0)} / 同じ日に日程の行が複数 #{summary.fetch(:ambiguous, 0)} / " \
         "日付が読めない #{summary.fetch(:bad_date, 0)} / 紐づけ先が違う #{summary.fetch(:mismatch, 0)}"
  end

  desc <<~DESC
    日程の種別 no_game の日を、シーズン作成元の日程マスタ（schedule_details）の種別に戻し、真偽値 no_game を真にする。cmd_1784 段4。
    ノーゲームの表し方を真偽値に一本化する（設計書 §4.6）。元のマスタは「そのシーズンと同じ日付の集合を持つ schedule」で引く。
    元の種別を決められない日（マスタが無い・割れる・マスタ自体が no_game）が 1 日でもあれば、APPLY=1 でも何も書かず止める。
    書くと登板の結果区分・疲労P が作り直される（画面でノーゲームを立てた時と同じ。登板の結果区分が no_game に変わり、疲労一覧の表示が変わる）。
    戻した種別が予備日などの試合日でない種別になる日は、一覧の not_game_type 行と標準出力に出す（種別は試合日でないまま真偽値だけが立つ）。
    既定は試運転（DB を書かない）。APPLY=1 の時だけ書く。何度流しても同じ結果になる（種別 no_game の日が無ければ 0 件）。
      bundle exec rake season_records:normalize_no_game_dates                    # 試運転
      OUT=/path/to/before.csv bundle exec rake season_records:normalize_no_game_dates  # 変更前後の値の CSV（逆向きに当てる材料）
      TEAM_ID=3 bundle exec rake season_records:normalize_no_game_dates          # チームを絞る
      APPLY=1 OUT=/path/to/before.csv bundle exec rake season_records:normalize_no_game_dates  # 実際に書く
      UNDO_FROM=/path/to/before.csv APPLY=1 bundle exec rake season_records:normalize_no_game_dates  # CSV から元に戻す
    CSV は schedule_id, season_id, team_id, team, date, old_date_type, old_no_game, new_date_type, new_no_game, status, master_types, pitcher_count の列。
    UNDO_FROM は、今の値が new_* と一致する行だけ old_* に戻す（食い違う行は戻さず一覧に出す）。UNDO_FROM は APPLY=1 でなければ試運転（読むだけ）。
  DESC
  task normalize_no_game_dates: :environment do
    apply = ENV["APPLY"] == "1"

    if ENV["UNDO_FROM"].present?
      csv_rows = CSV.read(ENV["UNDO_FROM"], headers: true).map(&:to_h).select { |r| r["status"] == "restore" }
      puts "# mode: UNDO #{apply ? 'APPLY (DB updated)' : 'DRY-RUN (DB unchanged)'}"
      if apply
        result = NoGameDateNormalizer.revert!(csv_rows)
        puts "# 戻した: #{result[:reverted]} 件 / 今の値が new_* と違うため戻さなかった: #{result[:skipped].size} 件 #{result[:skipped].inspect}"
      else
        current = csv_rows.count do |r|
          s = SeasonSchedule.find_by(id: r["schedule_id"])
          s && s.date_type == r["new_date_type"] && s.no_game == (r["new_no_game"] == "true")
        end
        puts "# 戻せる: #{current} 件 / 戻せない: #{csv_rows.size - current} 件（CSV #{csv_rows.size} 行）"
      end
      next
    end

    normalizer = NoGameDateNormalizer.new(team_id: ENV["TEAM_ID"]).call
    team_names = Team.where(id: normalizer.rows.map(&:team_id).uniq).pluck(:id, :name).to_h
    csv = CSV.generate do |out|
      out << %w[schedule_id season_id team_id team date old_date_type old_no_game new_date_type new_no_game status master_types pitcher_count]
      normalizer.rows.each do |r|
        out << [ r.schedule_id, r.season_id, r.team_id, team_names[r.team_id], r.date, r.old_date_type, r.old_no_game, r.new_date_type, r.new_no_game,
                 r.status, r.master_types.join(" "), r.pitcher_count ]
      end
    end
    if ENV["OUT"].present?
      File.write(ENV["OUT"], csv)
      puts "# CSV written: #{ENV['OUT']}（#{normalizer.rows.size} 行）"
    else
      puts csv
    end

    summary = normalizer.summary
    puts "# mode: #{apply ? 'APPLY (DB updated)' : 'DRY-RUN (DB unchanged)'}"
    puts "# 対象: #{ENV['TEAM_ID'].present? ? "チーム #{ENV['TEAM_ID']}" : '全チーム'} / 種別 no_game の日 #{normalizer.rows.size} 日（登板 #{normalizer.rows.sum(&:pitcher_count)} 件）"
    puts "# 戻す: #{summary.fetch(:restore, 0)} / 止める（元の種別を決められない）: マスタ無し #{summary.fetch(:unresolved, 0)} / 割れる #{summary.fetch(:ambiguous, 0)} / マスタが no_game #{summary.fetch(:master_no_game, 0)}"
    by_type = normalizer.rows.select { |r| r.status == :restore }.group_by(&:new_date_type).transform_values(&:size)
    puts "#   戻す種別: #{by_type.map { |k, v| "#{k} #{v}" }.join(' / ')}"
    normalizer.not_game_type.each do |r|
      puts "# 要確認(not_game_type): schedule #{r.schedule_id} チーム #{r.team_id} #{r.date} → #{r.new_date_type}（試合日でない種別のまま真偽値 no_game が立つ。登板 #{r.pitcher_count} 件）"
    end
    normalizer.stops.each { |r| puts "# 止める: schedule #{r.schedule_id} チーム #{r.team_id} #{r.date} #{r.status} #{r.master_types.inspect}" }

    if apply
      begin
        normalizer.apply!
        puts "# 書いた: #{normalizer.rows.size} 日"
      rescue NoGameDateNormalizer::Unresolved => e
        abort "# ERROR: #{e.message}"
      end
    end
  end
end
