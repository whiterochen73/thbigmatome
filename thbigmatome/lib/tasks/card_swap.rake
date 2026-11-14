require "csv"

namespace :cards do
  desc <<~DESC
    在籍中の所属のカードを、現行外の PM 系（PM2026）から現行の PM 系（PM2027）の同じ Player・同じ種別・同じ variant のカードへ付け替える。
    既定は dry-run（何を何に替えるかの CSV を出すだけ。同じ経路を流して巻き戻すので、検査の結果は実際の保存と同じに出る。DB は変わらない）。
      bundle exec rake cards:swap_to_current                                    # dry-run。要約を標準出力へ
      OUT=/path/plan.csv bundle exec rake cards:swap_to_current                 # 明細 CSV も書く
      APPLY=1 OUT=/path/plan.csv REVERT_OUT=/path/revert.csv bundle exec rake cards:swap_to_current   # 実行。戻し用 CSV（REVERT_OUT）が必須
    絞り込み（どれも任意）: TEAM_IDS=1,2,3  MEMBERSHIP_IDS=10,11  FROM_SETS=PM2026  TO_SETS=PM2027  DATE=YYYY-MM-DD（既定は各チームのシーズンの現在日）
    COMMISSIONER=1: 検査で止まらず警告つきで通す（既定は止めて理由を一覧に出す）
    戻す: bundle exec rake cards:revert_card_swap   （REVERT_CSV=戻し用 CSV。APPLY=1 で実行、無ければ dry-run）
  DESC
  task swap_to_current: :environment do
    apply = ENV["APPLY"] == "1"
    if apply && ENV["REVERT_OUT"].blank?
      abort "APPLY=1 には REVERT_OUT=<戻し用 CSV のパス> が必要です（元の player_card_id を残すため）"
    end

    list = ->(key) { ENV[key].to_s.split(",").map(&:strip).reject(&:empty?).presence }
    swap = PmCardSwap.new(
      team_ids: list.call("TEAM_IDS"), membership_ids: list.call("MEMBERSHIP_IDS"),
      from_sets: list.call("FROM_SETS"), to_sets: list.call("TO_SETS"),
      date: ENV["DATE"].presence, commissioner: ENV["COMMISSIONER"] == "1"
    )
    rows = swap.apply!(dry_run: !apply)

    if apply
      File.open(ENV["REVERT_OUT"], "w") { |f| PmCardSwap.revert_csv(rows, f) }
      puts "戻し用 CSV: #{ENV['REVERT_OUT']}"
    end
    File.open(ENV["OUT"], "w") { |f| PmCardSwap.plan_csv(rows, f) } if ENV["OUT"].present?

    puts "# cards:swap_to_current (#{apply ? 'APPLY' : 'dry-run。DB は変わっていない'})"
    puts "対象の所属: #{rows.size}"
    rows.group_by(&:status).sort.each { |status, list_| puts "  #{status}: #{list_.size}" }
    ok = rows.select { |r| %w[applied dry_run_ok].include?(r.status) }
    puts "  うちコストが変わる: #{ok.count(&:cost_changed)} / カードの中身が変わる: #{ok.count(&:content_changed)} / 時限つき: #{ok.count(&:time_limited)}"
    rows.reject { |r| %w[applied dry_run_ok].include?(r.status) }.each do |r|
      puts "  #{r.status}: team=#{r.team_id} membership=#{r.membership_id} #{r.player_name} (#{r.variant}) -> #{r.reason}"
    end
    ok.select { |r| r.cost_changed || r.content_changed || Array(r.warnings).any? }.each do |r|
      puts "  印: team=#{r.team_id} membership=#{r.membership_id} #{r.player_name} cost #{r.cost_before}->#{r.cost_after} content_changed=#{r.content_changed} warnings=#{Array(r.warnings).join(' / ')}"
    end
  end

  desc "cards:swap_to_current の戻し用 CSV（REVERT_CSV）で付け替えを戻す。APPLY=1 で実行、無ければ dry-run"
  task revert_card_swap: :environment do
    path = ENV["REVERT_CSV"].presence or abort "REVERT_CSV=<戻し用 CSV のパス> が必要です"
    apply = ENV["APPLY"] == "1"
    entries = CSV.read(path, headers: true).map(&:to_h)
    results = PmCardSwap.revert!(entries, dry_run: !apply)

    puts "# cards:revert_card_swap (#{apply ? 'APPLY' : 'dry-run。DB は変わっていない'})"
    puts "対象: #{results.size}"
    results.group_by { |r| r[:status] }.sort.each { |status, list_| puts "  #{status}: #{list_.size}" }
    results.reject { |r| r[:status] == "restored" && r[:reason].nil? }.each { |r| puts "  #{r[:status]}: membership=#{r[:membership_id]} #{r[:reason]}" }
  end
end
