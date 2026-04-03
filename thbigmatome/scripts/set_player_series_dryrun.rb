# set_player_series_dryrun.rb
# Player.series値設定のdry-run
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

# 優先度順（高い順）
PRIORITY = %w[hachinai tamayomi touhou original].freeze

def determine_series(player)
  card_set_ids = player.player_cards.pluck(:card_set_id).uniq
  return nil if card_set_ids.empty?

  series_set = card_set_ids.map { |id| CARD_SET_SERIES[id] }.compact.uniq

  # 単一シリーズ
  return series_set.first if series_set.size == 1

  # 複数シリーズ混在
  # hachinai + 他 → hachinai
  return 'hachinai' if series_set.include?('hachinai')
  # tamayomi + 他 → tamayomi
  return 'tamayomi' if series_set.include?('tamayomi')
  # touhou + original → touhou
  return 'touhou' if series_set.include?('touhou') && series_set.include?('original')

  # それ以外はPRIORITY順
  PRIORITY.find { |s| series_set.include?(s) }
end

puts "=== set_player_series DRY-RUN ==="
puts ""

results = Hash.new(0)
ambiguous = []
no_cards = []

Player.includes(:player_cards).find_each do |player|
  if player.player_cards.empty?
    # カードなし旧Player
    series = 'touhou'
    no_cards << { id: player.id, name: player.name, series: series }
    results[series] += 1
  else
    card_set_ids = player.player_cards.pluck(:card_set_id).uniq
    series_set = card_set_ids.map { |id| CARD_SET_SERIES[id] }.compact.uniq

    if series_set.size > 1
      series = determine_series(player)
      ambiguous << {
        id: player.id,
        name: player.name,
        card_sets: card_set_ids,
        series_set: series_set,
        determined: series
      }
    else
      series = series_set.first || 'touhou'
    end
    results[series] += 1
  end
end

puts "=== 分布予測 ==="
results.each { |s, c| puts "  #{s}: #{c}件" }
puts "  合計: #{results.values.sum}件 / Player総数: #{Player.count}件"
puts ""

puts "=== カードなし旧Player（デフォルトtouhou） ==="
puts "  #{no_cards.size}件"
no_cards.first(10).each do |p|
  puts "  id=#{p[:id]} #{p[:name]} → #{p[:series]}"
end
puts "  ...他省略" if no_cards.size > 10
puts ""

puts "=== 曖昧ケース（複数シリーズ混在） ==="
puts "  #{ambiguous.size}件"
ambiguous.each do |p|
  puts "  id=#{p[:id]} #{p[:name]}: sets=#{p[:series_set].join('+')} → #{p[:determined]}"
end
puts ""

puts "=== nil残存予測 ==="
nil_count = Player.count - results.values.sum
puts "  nil残存: #{nil_count}件"
puts ""
puts "DRY-RUN完了。本実行は set_player_series.rb で実施。"
