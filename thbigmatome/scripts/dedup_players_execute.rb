# frozen_string_literal: true

# scripts/dedup_players_execute.rb
# Player ID二重化解消 本実行
# 旧Player (id < 380) を正として、新PlayerのカードFKを付け替え → 空の新Playerを削除
#
# 判断: karo 2026-03-10
# - 複数候補（同名旧Player2件）は参照数（team_memberships+cost_players）が多い方を選択
# - 両方0件ならIDが小さい方（小さいID = 先に登録）を選択

puts "=== Player ID二重化解消 本実行 ==="
puts ""

def normalize_name(name)
  return "" if name.nil?
  name.gsub(/[\u3000\s]/, "").strip
end

old_players = Player.where("id < 380").to_a
new_players = Player.where("id >= 380").to_a

puts "旧Player (id < 380): #{old_players.size}件"
puts "新Player (id >= 380): #{new_players.size}件"
puts ""

old_by_name = old_players.each_with_object({}) do |p, h|
  key = normalize_name(p.name)
  h[key] ||= []
  h[key] << p
end

matched_pairs = []
unmatched_new = []

new_players.each do |np|
  key = normalize_name(np.name)
  candidates = old_by_name[key] || []

  if candidates.size >= 1
    if candidates.size == 1
      chosen = candidates.first
    else
      # 複数候補: team_memberships + cost_players の参照数が多い方を選択、両方0件ならIDが小さい方
      chosen = candidates.max_by do |p|
        refs = p.team_memberships.count + p.cost_players.count
        [ refs, -p.id ]  # 参照数の多い方、同数ならIDが小さい方（-id で小さいIDが優先）
      end
    end
    card_count = PlayerCard.where(player_id: np.id).count
    matched_pairs << { old: chosen, new: np, card_count: card_count }
  else
    unmatched_new << np
  end
end

puts "マッチ組数: #{matched_pairs.size}件（マッチ163 + 複数候補34）"
puts "対応なし新Player（スキップ）: #{unmatched_new.size}件"
puts ""

updated_count = 0
deleted_count = 0

ActiveRecord::Base.transaction do
  puts "--- トランザクション開始 ---"

  matched_pairs.each do |pair|
    old_player = pair[:old]
    new_player = pair[:new]

    # player_cards.player_id を旧Player IDに UPDATE
    moved = PlayerCard.where(player_id: new_player.id).update_all(player_id: old_player.id)
    updated_count += moved

    if moved > 0
      puts "  移動: 新[#{new_player.id}]#{new_player.name} → 旧[#{old_player.id}]#{old_player.name} (#{moved}cards)"
    end

    # 移動後、新Playerに残っているPlayerCardを確認
    remaining = PlayerCard.where(player_id: new_player.id).count
    if remaining == 0
      new_player.destroy!
      deleted_count += 1
    else
      puts "  ⚠️  新[#{new_player.id}]に#{remaining}cardsが残存 — 削除スキップ"
    end
  end

  puts ""
  puts "--- FK整合性チェック ---"
  orphan_cards = PlayerCard.where.not(player_id: Player.pluck(:id)).count
  orphan_cost = CostPlayer.where.not(player_id: Player.pluck(:id)).count
  orphan_membership = TeamMembership.where.not(player_id: Player.pluck(:id)).count

  if orphan_cards > 0 || orphan_cost > 0 || orphan_membership > 0
    puts "  ❌ orphan検出！ cards=#{orphan_cards}, cost=#{orphan_cost}, membership=#{orphan_membership}"
    puts "  ロールバックします"
    raise ActiveRecord::Rollback
  else
    puts "  ✅ orphanなし"
  end

  puts "--- トランザクション完了 ---"
end

puts ""
puts "=== 実行結果サマリー ==="
puts "PlayerCard移動件数: #{updated_count}件"
puts "削除した新Playerレコード: #{deleted_count}件"
puts "スキップした新Player（対応なし）: #{unmatched_new.size}件"
puts ""
puts "=== 整合性最終確認 ==="
puts "Player総数: #{Player.count}"
puts "PlayerCard総数: #{PlayerCard.count}"
puts "旧Player(id<380)残存: #{Player.where('id < 380').count}"
puts "新Player(id>=380)残存: #{Player.where('id >= 380').count}"
puts "PlayerCard orphan: #{PlayerCard.where.not(player_id: Player.pluck(:id)).count}"
puts "CostPlayer orphan: #{CostPlayer.where.not(player_id: Player.pluck(:id)).count}"
puts "TeamMembership orphan: #{TeamMembership.where.not(player_id: Player.pluck(:id)).count}"
puts ""
puts "本実行完了"
