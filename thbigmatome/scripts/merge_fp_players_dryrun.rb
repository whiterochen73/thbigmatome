# dry-run: F/P重複Player統合シミュレーション (subtask_523b)
# 実行: docker compose exec rails rails runner scripts/merge_fp_players_dryrun.rb

puts "=== F/P重複Player統合 dry-run ==="
puts "実行時刻: #{Time.now}"
puts ""

# 旧Player(id < 380)を対象に名前・背番号のF/Pペアを特定
old_players = Player.where("id < ?", 380).order(:id)
puts "旧Player総数: #{old_players.count}"

# 背番号からF/Pプレフィックスを除去して数字を正規化
def normalize_number(num)
  return nil if num.nil?
  num.gsub(/\A[FP]/, "")
end

# 名前を正規化（全角・半角スペース除去）
def normalize_name(name)
  return nil if name.nil?
  name.gsub(/[\s　]/, "")
end

# F/Pペアの検出
f_players = old_players.select { |p| p.number&.match?(/\AF\d/) }
p_players = old_players.select { |p| p.number&.match?(/\AP\d/) }

puts "F版Player数: #{f_players.count}"
puts "P版Player数: #{p_players.count}"
puts ""

pairs = []
unmatched_f = []
unmatched_p = p_players.dup

f_players.each do |fp|
  norm_name = normalize_name(fp.name)
  norm_num  = normalize_number(fp.number)

  match = p_players.find do |pp|
    normalize_name(pp.name) == norm_name &&
      normalize_number(pp.number) == norm_num
  end

  if match
    unmatched_p.delete(match)

    # 統合先の決定: team_membershipsを持つ側を優先、なければF版
    fp_tm    = fp.team_memberships.count
    match_tm = match.team_memberships.count

    if match_tm > fp_tm
      dest, src = match, fp
    else
      dest, src = fp, match
    end

    pairs << { dest: dest, src: src }
  else
    unmatched_f << fp
  end
end

puts "=== ペア検出結果: #{pairs.count}組 ==="
puts ""

collision_count = 0
pairs.each_with_index do |pair, i|
  dest = pair[:dest]
  src  = pair[:src]

  new_number = normalize_number(dest.number)

  # 背番号衝突チェック（自分自身と同ペアは除外）
  exclude_ids = [ dest.id, src.id ]
  collision = Player.where(number: new_number)
                    .where.not(id: exclude_ids)
                    .exists?

  dest_pc = dest.player_cards.count
  src_pc  = src.player_cards.count
  dest_cp = dest.cost_players.count
  src_cp  = src.cost_players.count
  dest_tm = dest.team_memberships.count
  src_tm  = src.team_memberships.count

  collision_flag = collision ? " ⚠️ 背番号衝突!" : ""
  collision_count += 1 if collision

  puts "[#{i + 1}] 統合先: id=#{dest.id} #{dest.name}(#{dest.number}) → 背番号=#{new_number}#{collision_flag}"
  puts "     統合元: id=#{src.id} #{src.name}(#{src.number})"
  puts "     player_cards: #{dest_pc}(統合先) + #{src_pc}(統合元) = #{dest_pc + src_pc}"
  puts "     cost_players: #{dest_cp}(統合先) + #{src_cp}(統合元) ※重複はスキップ"
  puts "     team_memberships: #{dest_tm}(統合先) + #{src_tm}(統合元)"
  puts ""
end

puts "=== サマリー ==="
puts "ペア数: #{pairs.count}組"
puts "背番号衝突: #{collision_count}件"
puts "未マッチF版: #{unmatched_f.count}件 #{unmatched_f.map { |p| "#{p.id}:#{p.name}(#{p.number})" }.join(', ')}"
puts "未マッチP版: #{unmatched_p.count}件 #{unmatched_p.map { |p| "#{p.id}:#{p.name}(#{p.number})" }.join(', ')}"
puts ""
puts "dry-run完了。本実行はmerge_fp_players_execute.rbを使用すること。"
