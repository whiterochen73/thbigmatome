# frozen_string_literal: true

# scripts/dedup_players_dryrun.rb
# Player ID二重化解消 dry-run
# 旧Player (id < 380): team_memberships, cost_players が参照
# 新Player (id >= 380): player_cards, player_card_defenses が参照
# dry-runのみ — DBは変更しない

puts "=== Player ID二重化解消 dry-run ==="
puts ""

# 名前を正規化（全角・半角スペース除去、strip）
def normalize_name(name)
  return "" if name.nil?
  name.gsub(/[\u3000\s]/, "").strip
end

old_players = Player.where("id < 380").to_a
new_players = Player.where("id >= 380").to_a

puts "旧Player (id < 380): #{old_players.size}件"
puts "新Player (id >= 380): #{new_players.size}件"
puts ""

# 旧Playerを正規化名でindexを作成
old_by_name = old_players.each_with_object({}) do |p, h|
  key = normalize_name(p.name)
  h[key] ||= []
  h[key] << p
end

matched_pairs = []
multi_match_warnings = []
unmatched_new = []

new_players.each do |np|
  key = normalize_name(np.name)
  candidates = old_by_name[key] || []

  if candidates.size == 1
    op = candidates.first
    card_count = PlayerCard.where(player_id: np.id).count
    matched_pairs << { old: op, new: np, card_count: card_count }
  elsif candidates.size > 1
    multi_match_warnings << { new: np, candidates: candidates }
  else
    unmatched_new << np
  end
end

puts "=== マッチング結果 ==="
puts "マッチ組数: #{matched_pairs.size}件"
puts ""

if matched_pairs.any?
  puts "--- マッチ一覧（旧ID / 旧名 / 新ID / 新名 / 移動対象PlayerCard数）---"
  matched_pairs.each do |pair|
    puts "  旧[#{pair[:old].id}] #{pair[:old].name} ← 新[#{pair[:new].id}] #{pair[:new].name} | PlayerCards: #{pair[:card_count]}件"
  end
  puts ""
end

if multi_match_warnings.any?
  puts "=== ⚠️  複数候補警告（同名旧Playerが複数存在）==="
  multi_match_warnings.each do |w|
    puts "  新[#{w[:new].id}] #{w[:new].name} → 旧候補: #{w[:candidates].map { |c| "[#{c.id}]#{c.name}" }.join(', ')}"
  end
  puts ""
end

puts "=== 対応なし新Player（旧に対応なし）==="
puts "件数: #{unmatched_new.size}件"
if unmatched_new.any?
  unmatched_new.each do |p|
    card_count = PlayerCard.where(player_id: p.id).count
    puts "  新[#{p.id}] #{p.name} | PlayerCards: #{card_count}件"
  end
end

puts ""
puts "=== サマリー ==="
total_cards_to_move = matched_pairs.sum { |p| p[:card_count] }
puts "マッチ組数: #{matched_pairs.size}件"
puts "移動予定PlayerCard総数: #{total_cards_to_move}件"
puts "複数候補警告: #{multi_match_warnings.size}件"
puts "対応なし新Player: #{unmatched_new.size}件"
puts ""
puts "dry-run完了 — DBは変更していません"

if multi_match_warnings.any?
  puts ""
  puts "⚠️  複数候補が#{multi_match_warnings.size}件あります。karoへ報告して判断を仰いでください。"
end
