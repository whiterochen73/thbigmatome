# dry_run_516.rb
# 旧Player(id<380) と 新Player(id>=380) の名前マッチングを確認

old_players = Player.where('id < 380').index_by { |p| p.name.gsub(/[[:space:]]/, '') }
new_players = Player.where('id >= 380')

matched = []
unmatched = []
new_players.each do |np|
  key = np.name.gsub(/[[:space:]]/, '')
  if old_players[key]
    matched << { new_id: np.id, new_name: np.name, old_id: old_players[key].id, old_name: old_players[key].name }
  else
    unmatched << { new_id: np.id, new_name: np.name }
  end
end

puts "=== マッチ結果 ==="
puts "マッチ: #{matched.count}件"
puts "アンマッチ（旧に対応なし＝新規選手）: #{unmatched.count}件"
puts ""
puts "=== 移行対象PlayerCard確認 ==="
matched.each do |m|
  pc_count = PlayerCard.where(player_id: m[:new_id]).count
  puts "#{m[:new_name]}(new:#{m[:new_id]} → old:#{m[:old_id]}): PlayerCard #{pc_count}件"
end

puts ""
puts "=== アンマッチ一覧 ==="
unmatched.each do |u|
  pc_count = PlayerCard.where(player_id: u[:new_id]).count
  puts "#{u[:new_name]}(id:#{u[:new_id]}): PlayerCard #{pc_count}件"
end

puts ""
puts "=== 現状サマリ ==="
puts "旧Player(id<380): #{Player.where('id < 380').count}件"
puts "新Player(id>=380): #{Player.where('id >= 380').count}件"
puts "PlayerCard total: #{PlayerCard.count}件"
puts "PlayerCard→旧Player参照: #{PlayerCard.joins(:player).where('players.id < 380').count}件"
puts "PlayerCard→新Player参照: #{PlayerCard.joins(:player).where('players.id >= 380').count}件"
