# db/scripts/check_507_prereq.rb
# cmd_507事前確認: cmd_506で登録したCostPlayerとPM2026 PlayerCardの状態確認

cost = Cost.find_by(name: "2025年12月コスト改定")
pm2026 = CardSet.find_by(name: "PM2026")

puts "Cost: id=#{cost&.id} #{cost&.name}"
puts "PM2026 CardSet: id=#{pm2026&.id}"
puts ""

# cmd_506スクリプトに記載のPlayer一覧
sec1_player_ids = [ 586, 567, 560, 587, 585, 569, 561, 583, 573, 618, 619, 617, 590, 609, 600, 588, 589 ]
sec2_names = [
  "ゆだ2", "mori3", "けいようし2", "ベルン", "cyan2",
  "摩多羅 隠岐奈 (天保山)", "坂田 ネムノ (安曇野)", "永江 衣玖 (最上川)",
  "藤原 妹紅 (信楽)", "今泉 影狼 (下館)", "椎名 ゆかり (那珂川)", "菅牧 典 (小牧)",
  "中野綾香 (UR)", "小鳥遊柚 (UR)", "初瀬麻里安 (UR)"
]

puts "=== sec1 既存Player ==="
Player.where(id: sec1_player_ids).order(:id).each do |p|
  cp = CostPlayer.find_by(cost: cost, player: p)
  pc = PlayerCard.find_by(card_set: pm2026, player: p)
  cp_str = cp ? "CP(nc=#{cp.normal_cost})" : "NO_CP"
  pc_str = pc ? "PC##{pc.id}" : "NO_PC"
  puts "  id=#{p.id} ##{p.number} #{p.name}: #{cp_str}, #{pc_str}"
end

puts ""
puts "=== sec2 新規Player ==="
sec2_names.each do |name|
  p = Player.find_by(name: name)
  if p
    cp = CostPlayer.find_by(cost: cost, player: p)
    pc = PlayerCard.find_by(card_set: pm2026, player: p)
    cp_str = cp ? "CP(nc=#{cp.normal_cost})" : "NO_CP"
    pc_str = pc ? "PC##{pc.id}" : "NO_PC"
    puts "  id=#{p.id} ##{p.number} #{p.name}: #{cp_str}, #{pc_str}"
  else
    puts "  '#{name}': PLAYER_NOT_FOUND"
  end
end

puts ""
puts "=== PM2026 既存PlayerCard総数 ==="
puts "  #{PlayerCard.where(card_set: pm2026).count}件"
