cost = Cost.find_by(name: '2025年12月コスト改定')
puts '=== 追加確認 ==='

# PM players - 未確認分
check = {
  'ゆだ2' => [ 'ゆだ2', 'ゆだ (2)' ],
  'ベルン' => [ 'ベルン' ],
  'マゼラン' => [ 'マゼラン' ],
  'Judah' => [ 'Judah' ],
  '摩多羅(天保山)' => [ '摩多羅 隠岐奈 (天保山)', '摩多羅(天保山)', '摩多羅 隠岐奈(天保山)' ],
  '坂田ネムノ(安曇野)' => [ '坂田 ネムノ (安曇野)', '坂田ネムノ(安曇野)', '坂田　ネムノ (安曇野)' ],
  '衣玖(最上川)' => [ '永江 衣玖 (最上川)', '永江　衣玖 (最上川)', '衣玖(最上川)' ],
  '藤原妹紅(信楽)' => [ '藤原 妹紅 (信楽)', '藤原　妹紅 (信楽)', '藤原妹紅(信楽)' ],
  '影狼(下館)' => [ '今泉 影狼 (下館)', '今泉　影狼 (下館)' ],
  '菅牧典(小牧)' => [ '菅牧 典 (小牧)', '菅牧　典 (小牧)' ],
  '中野綾香(UR)' => [ '中野 綾香 (UR)', '中野綾香(UR)', '中野　綾香 (UR)' ],
  '小鳥遊柚(UR)' => [ '小鳥遊 柚 (UR)', '小鳥遊柚(UR)', '小鳥遊　柚 (UR)' ],
  '初瀬麻里安(UR)' => [ '初瀬 麻里安 (UR)', '初瀬　麻里安 (UR)', '初瀬麻里安(UR)' ]
}

check.each do |label, names|
  found = nil
  names.each do |n|
    found = Player.find_by(name: n)
    break if found
  end
  if found
    cp = CostPlayer.find_by(cost: cost, player: found)
    puts "#{label}: Player##{found.id}(#{found.number}) '#{found.name}' CostPlayer=#{cp ? cp.id : 'NONE'}"
  else
    puts "#{label}: NOT FOUND"
  end
end

# マゼランの全候補
puts ''
puts '=== マゼラン全候補 ==='
Player.where('name LIKE ?', '%マゼラン%').each do |p|
  cp = CostPlayer.find_by(cost: cost, player: p)
  puts "  ##{p.number} '#{p.name}' CostPlayer=#{cp ? cp.id : 'NONE'}"
end

# PM2026の最大番号 (player_cards経由)
puts ''
puts '=== PM2026 players (player_cards) last numbers ==='
Player.joins(:player_cards).where(player_cards: { card_set_id: 3 }).pluck(:number, :name).sort_by { |n, _| n.to_i }.last(5).each do |n, name|
  puts "  #{n}: #{name}"
end
