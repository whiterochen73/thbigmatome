require "csv"

namespace :season_records do
  desc <<~DESC
    シーズン記録の食い違いを数えて一覧にする（読むだけ。DB へは一切書かない）。cmd_1784 段0。
    設計書 context/thbig-dugout-season-record-restructure-design.md §1.3 の S1・S2・S7・S8・S10・S11 を数える。
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
    puts "試合日とみなす種別の集合（S11。場所ごとに違う）:"
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
        state = RosterState.new(team, memberships: team.team_memberships.preload(:season_rosters, :player).to_a)
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
end
