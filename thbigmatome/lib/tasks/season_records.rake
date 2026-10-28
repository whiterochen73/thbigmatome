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
end
