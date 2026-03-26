require "csv"

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

    # 全角/半角スペース差異を吸収した正規化マッチ
    raw_name = row["player_name"]
    normalized_name = raw_name.gsub(/[\s\u3000]+/, '')
    player = Player.find_by("REPLACE(REPLACE(name, ' ', ''), '　', '') = ?", normalized_name)
    unless player
      puts "  WARN: player '#{raw_name}' not found — skipped"
      skipped += 1
      next
    end

    cp = CostPlayer.find_or_initialize_by(cost: cost, player: player)
    cp.normal_cost       = row["normal_cost"].presence&.to_i
    cp.relief_only_cost  = row["relief_only_cost"].presence&.to_i
    cp.pitcher_only_cost = row["pitcher_only_cost"].presence&.to_i
    cp.fielder_only_cost = row["fielder_only_cost"].presence&.to_i
    cp.two_way_cost      = row["two_way_cost"].presence&.to_i
    cp.cost_exempt       = row["cost_exempt"] == "true"
    cp.save!
    imported += 1
  end
  puts "  #{imported} cost_players seeded, #{skipped} skipped."
end
