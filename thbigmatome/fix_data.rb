["丁礼田　舞", "爾子田　里乃"].each do |name|
  player = Player.find_by(name: name)
  if player
    cp = player.cost_players.find_by(cost_id: 1)
    if cp
      puts "#{name}: #{cp.normal_cost} -> 6"
      cp.update!(normal_cost: 6) if cp.normal_cost == 7
    else
      puts "#{name}: cost_id=1 not found"
    end
  else
    puts "#{name}: player not found"
  end
end
p = Player.find_by(name: '二ッ岩　マミゾウ')
if p
  puts "#{p.name} -> 二ツ岩　マミゾウ"
  p.update!(name: '二ツ岩　マミゾウ')
else
  puts '二ッ岩　マミゾウ: player not found'
end
puts 'Done'
