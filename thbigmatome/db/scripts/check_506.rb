cost = Cost.find_by(name: '2025年12月コスト改定')
puts 'Cost ID: ' + cost.id.to_s

# 既存Playerでコストあるか確認
check_names = [ '聖 白蓮 (佐世保)', '小悪魔 (時津)', '洩矢 諏訪子(茨木)', 'ナズーリン (厚木)', '近藤 咲(桜木町)', '有原 翼 (里ヶ浜)', 'ヘカーティア・L (ポートランド)', 'ひいらぎ', 'ふぁん', 'じょーかー', 'ガブリチュウ', 'pontiti', 'れもん', 'takky', 'mori (3)', 'けいようし (2)', 'cyan (2)', 'マゼラン (2)', 'Judah (2)', '椎名 ゆかり (那珂川)' ]
check_names.each do |name|
  p = Player.find_by(name: name)
  if p
    cp = CostPlayer.find_by(cost: cost, player: p)
    puts "#{name}: Player##{p.id}(#{p.number}) CostPlayer=#{cp ? cp.id : 'NONE'}"
  else
    puts "#{name}: Player NOT FOUND"
  end
end

puts ''
puts 'PM2026 max number (numerical):'
pm_players = Player.joins(:card_set).where(card_sets: { name: 'PM2026' }).pluck(:number)
puts pm_players.map(&:to_i).max
puts 'All PM2026 numbers (sorted numerically, last 10):'
puts pm_players.sort_by(&:to_i).last(10).inspect
