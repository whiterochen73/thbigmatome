# set_player_series.rb
# Player.series値設定（本実行）
# CardSet ID対応:
#   1: 2025THBIG (touhou)
#   2: ハチナイ6.1 (hachinai)
#   3: PM2026 (original)
#   4: 球詠2 (tamayomi)

CARD_SET_SERIES = {
  1 => 'touhou',
  2 => 'hachinai',
  3 => 'original',
  4 => 'tamayomi'
}.freeze

def determine_series(series_set)
  return series_set.first if series_set.size == 1
  return 'hachinai' if series_set.include?('hachinai')
  return 'tamayomi' if series_set.include?('tamayomi')
  return 'touhou' if series_set.include?('touhou') && series_set.include?('original')
  series_set.first
end

puts "=== set_player_series 本実行 ==="
puts ""

updated = 0
results = Hash.new(0)

Player.includes(:player_cards).find_each do |player|
  if player.player_cards.empty?
    series = 'touhou'
  else
    card_set_ids = player.player_cards.pluck(:card_set_id).uniq
    series_set = card_set_ids.map { |id| CARD_SET_SERIES[id] }.compact.uniq
    series = series_set.empty? ? 'touhou' : determine_series(series_set)
  end

  player.update_column(:series, series)
  results[series] += 1
  updated += 1
end

puts "=== 完了 ==="
puts "更新件数: #{updated}件"
puts ""
puts "=== series分布 ==="
results.each { |s, c| puts "  #{s}: #{c}件" }
puts ""

puts "=== nil残存確認 ==="
nil_count = Player.where(series: nil).count
puts "  nil残存: #{nil_count}件"
puts ""

if nil_count == 0
  puts "✓ 全Playerにseries値が設定されました"
else
  puts "✗ nil残存あり。要調査:"
  Player.where(series: nil).each { |p| puts "  id=#{p.id} #{p.name}" }
end
