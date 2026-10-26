require "csv"

namespace :pitcher_game_states do
  desc <<~DESC
    先発の result_category と fatigue_p_used を、試合概要の得点とカード（試合前のスタミナ補正込み）から作り直す。
    連続中4日カウント（consecutive_short_rest_count）も同じ走査で埋め直す（直前の先発との中日数が中4日なら前回値+1、
    それ以外は 0。中日数から引く離脱は負傷のみ）。カウントは得点・カードに依らないので、区分を作り直せない行でも書く。
    既定は試運転（DB を書かない）。APPLY=1 の時だけ書く。
      bundle exec rake pitcher_game_states:recalculate_result_category              # 試運転（CSV を標準出力）
      APPLY=1 bundle exec rake pitcher_game_states:recalculate_result_category      # 実際に書く
      TEAM_ID=3 bundle exec rake pitcher_game_states:recalculate_result_category    # チームを絞る
      OUT=/path/to/dry_run.csv bundle exec rake ...                                 # CSV をファイルへ
    投手ごとに日付順に処理し、作り直した値を次の登板の補正に使う。
    カード未特定・得点未入力・試合概要なし・ノーゲームは変えずに件数を出す。
  DESC
  task recalculate_result_category: :environment do
    apply = ENV["APPLY"] == "1"
    rebuilder = PitcherResultCategoryRebuilder.new(apply: apply)

    ActiveRecord::Base.transaction do
      rebuilder.rebuild_all(team_id: ENV["TEAM_ID"].presence)
    end

    team_names = Team.where(id: rebuilder.rows.map(&:team_id).uniq).pluck(:id, :name).to_h
    pitcher_names = Player.where(id: rebuilder.rows.map(&:pitcher_id).uniq).pluck(:id, :name).to_h

    csv = CSV.generate do |out|
      out << %w[team_id team date pitcher_id pitcher old_category new_category old_fatigue_p new_fatigue_p game_result status
                old_consecutive_short_rest_count new_consecutive_short_rest_count]
      # 区分が変わる行と、連続中4日カウントが変わる行を出す
      rebuilder.rows.select { |r| r.status == :changed || r.consecutive_changed? }.each do |r|
        out << [ r.team_id, team_names[r.team_id], r.schedule_date, r.pitcher_id, pitcher_names[r.pitcher_id],
                 r.old_category, r.new_category, r.old_fatigue_p, r.new_fatigue_p, r.game_result, r.status,
                 r.old_consecutive_short_rest_count, r.new_consecutive_short_rest_count ]
      end
    end

    if ENV["OUT"].present?
      File.write(ENV["OUT"], csv)
      puts "# CSV written: #{ENV['OUT']}"
    else
      puts csv
    end

    summary = rebuilder.summary
    puts "# mode: #{apply ? 'APPLY (DB updated)' : 'DRY-RUN (DB unchanged)'}"
    puts "# changed(区分が変わる): #{summary.fetch(:changed, 0)}"
    puts "# fatigue_only(区分は同じ・疲労Pだけ変わる): #{summary.fetch(:fatigue_only, 0)}"
    puts "# unchanged: #{summary.fetch(:unchanged, 0)}"
    puts "# consecutive_short_rest_count が変わる: #{rebuilder.consecutive_changed_count}"
    puts "# skipped_unscored(得点未入力): #{summary.fetch(:skipped_unscored, 0)}"
    puts "# skipped_no_schedule(試合概要なし): #{summary.fetch(:skipped_no_schedule, 0)}"
    puts "# skipped_ambiguous_schedule(試合概要が複数): #{summary.fetch(:skipped_ambiguous_schedule, 0)}"
    puts "# skipped_no_game(ノーゲーム): #{summary.fetch(:skipped_no_game, 0)}"
    pending = rebuilder.rows.select { |r| r.status == :pending }
    puts "# pending(判定保留): #{pending.size}"
    pending.group_by(&:reason).each do |reason, rs|
      puts "#   #{reason}: #{rs.size} (#{PitcherResultCategory.pending_message(reason)})"
    end
  end
end
