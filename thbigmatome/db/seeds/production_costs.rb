require "csv"
require Rails.root.join("lib/cost_player_seed_resolver").to_s

# db/seeds/production_costs.rb
# コストマスタ + コストプレイヤー seedデータ
# 注意: このファイルはPlayers（import:card_data）投入後に実行すること

puts "Seeding Costs..."
costs_data = [
  { name: "2024年12月コスト改定", start_date: "2024-12-14", end_date: "2025-12-27" },
  { name: "2025年12月コスト改定", start_date: "2025-12-28", end_date: nil }
]
costs_data.each do |attrs|
  cost = Cost.find_or_initialize_by(name: attrs[:name])
  cost.update!(start_date: attrs[:start_date], end_date: attrs[:end_date])
end
puts "  #{Cost.count} costs seeded."

puts "Seeding CostPlayers from CSV..."
csv_path = Rails.root.join("db/import/cost_players_seed.csv")
unless File.exist?(csv_path)
  puts "  SKIP: #{csv_path} not found"
else
  skipped = 0
  imported = 0
  CSV.foreach(csv_path, headers: true) do |row|
    cost = Cost.find_by(name: row["cost_name"])
    unless cost
      puts "  WARN: cost '#{row['cost_name']}' not found — skipped"
      skipped += 1
      next
    end

    raw_name = row["player_name"]
    cp = CostPlayerSeedResolver.assign!(cost, row)
    unless cp
      puts "  WARN: player '#{raw_name}' not found — skipped"
      skipped += 1
      next
    end

    imported += 1
  end
  puts "  #{imported} cost_players seeded, #{skipped} skipped."
end
