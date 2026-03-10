# 本実行: F/P重複Player統合 (subtask_523b)
# 実行: docker compose exec rails rails runner scripts/merge_fp_players_execute.rb

puts "=== F/P重複Player統合 本実行 ==="
puts "実行時刻: #{Time.now}"
puts ""

conn = ActiveRecord::Base.connection

def normalize_number(num)
  return nil if num.nil?
  num.gsub(/\A[FP]/, "")
end

def normalize_name(name)
  return nil if name.nil?
  name.gsub(/[\s　]/, "")
end

# 統合先IDが決まったら、以下のテーブルをsrc→destに更新する
# 廃止予定テーブルはsrcを削除するだけでOK
def migrate_player_references(conn, src_id, dest_id)
  results = {}

  # ゲーム系テーブル（移行）
  [
    [ "at_bats", "batter_id" ],
    [ "at_bats", "pitcher_id" ],
    [ "at_bats", "pinch_hit_for_id" ],
    [ "season_schedules", "winning_pitcher_id" ],
    [ "season_schedules", "losing_pitcher_id" ],
    [ "season_schedules", "save_pitcher_id" ],
    [ "pitcher_game_states", "pitcher_id" ],
    [ "imported_stats", "player_id" ],
    [ "lineup_template_entries", "player_id" ],
    [ "player_card_exclusive_catchers", "catcher_player_id" ]
  ].each do |table, col|
    next unless conn.table_exists?(table)
    count = conn.execute(
      "UPDATE #{table} SET #{col} = #{dest_id} WHERE #{col} = #{src_id}"
    ).cmd_tuples
    results["#{table}.#{col}"] = count if count > 0
  end

  # 廃止予定テーブル (player_player_types, catchers_players, player_batting_skills, player_pitching_skills, league_pool_players)
  # → player_player_types は unique制約があるので移行(重複スキップ)、他は削除のみ
  if conn.table_exists?('player_player_types')
    dest_type_ids = conn.execute(
      "SELECT player_type_id FROM player_player_types WHERE player_id = #{dest_id}"
    ).map { |r| r["player_type_id"] }

    moved = 0
    conn.execute(
      "SELECT player_type_id FROM player_player_types WHERE player_id = #{src_id}"
    ).each do |row|
      unless dest_type_ids.include?(row["player_type_id"])
        conn.execute(
          "UPDATE player_player_types SET player_id = #{dest_id} WHERE player_id = #{src_id} AND player_type_id = #{row['player_type_id']}"
        )
        moved += 1
      end
    end
    conn.execute("DELETE FROM player_player_types WHERE player_id = #{src_id}")
    results["player_player_types"] = "moved:#{moved}" if moved > 0
  end

  [
    [ "catchers_players", "catcher_id" ],
    [ "catchers_players", "player_id" ],
    [ "player_batting_skills", "player_id" ],
    [ "player_pitching_skills", "player_id" ],
    [ "league_pool_players", "player_id" ]
  ].each do |table, col|
    next unless conn.table_exists?(table)
    count = conn.execute(
      "DELETE FROM #{table} WHERE #{col} = #{src_id}"
    ).cmd_tuples
    results["#{table}.#{col}(del)"] = count if count > 0
  end

  results
end

# 旧Player(id < 380)のみ対象
old_players = Player.where("id < ?", 380).order(:id).to_a
f_players   = old_players.select { |p| p.number&.match?(/\AF\d/) }
p_players   = old_players.select { |p| p.number&.match?(/\AP\d/) }

pairs = []
p_players_dup = p_players.dup

f_players.each do |fp|
  norm_name = normalize_name(fp.name)
  norm_num  = normalize_number(fp.number)

  match = p_players.find do |pp|
    normalize_name(pp.name) == norm_name &&
      normalize_number(pp.number) == norm_num
  end

  next unless match

  p_players_dup.delete(match)

  fp_tm    = fp.team_memberships.count
  match_tm = match.team_memberships.count

  if match_tm > fp_tm
    dest, src = match, fp
  else
    dest, src = fp, match
  end

  pairs << { dest: dest, src: src }
end

puts "対象ペア数: #{pairs.count}組"
puts ""

merged_count  = 0
deleted_count = 0
skipped_cp    = 0

ActiveRecord::Base.transaction do
  pairs.each_with_index do |pair, i|
    dest = pair[:dest]
    src  = pair[:src]

    puts "[#{i + 1}] #{dest.name}: id=#{src.id}(#{src.number}) → id=#{dest.id}(#{dest.number})"

    # a. player_cards を統合先に更新
    pc_count = PlayerCard.where(player_id: src.id).update_all(player_id: dest.id)
    puts "     player_cards移行: #{pc_count}件" if pc_count > 0

    # b. cost_players を統合先に更新（重複スキップ）
    src.cost_players.reload.each do |src_cp|
      if dest.cost_players.exists?(cost_id: src_cp.cost_id)
        puts "     cost_player(cost_id=#{src_cp.cost_id}) スキップ（重複）"
        skipped_cp += 1
        src_cp.destroy!
      else
        src_cp.update!(player_id: dest.id)
      end
    end

    # c. team_memberships を統合先に更新（あれば）
    tm_count = TeamMembership.where(player_id: src.id).update_all(player_id: dest.id)
    puts "     team_memberships移行: #{tm_count}件" if tm_count > 0

    # d. 全FK参照テーブルを処理
    ref_results = migrate_player_references(conn, src.id, dest.id)
    ref_results.each { |k, v| puts "     #{k}: #{v}" }

    # e. 統合元Playerを削除
    src.destroy!
    deleted_count += 1

    # f. 統合先の背番号からF/Pプレフィックスを除去
    old_number = dest.number
    new_number = normalize_number(old_number)
    if old_number != new_number
      dest.update!(number: new_number)
      puts "     背番号更新: #{old_number} → #{new_number}"
    end

    merged_count += 1
  end
end

puts ""
puts "=== 本実行サマリー ==="
puts "統合ペア数: #{merged_count}組"
puts "削除Player数: #{deleted_count}件"
puts "CostPlayerスキップ数: #{skipped_cp}件"
puts "完了時刻: #{Time.now}"
