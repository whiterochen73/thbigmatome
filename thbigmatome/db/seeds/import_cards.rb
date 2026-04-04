require "csv"

# db/seeds/import_cards.rb
# 選手カードデータをCSVからインポートする（import:card_data rakeタスクと同ロジック）
# CSVソース: db/import/ ディレクトリ

def derive_handedness(throwing, batting)
  throw_part = case throwing
  when "right" then "right_throw"
  when "left"  then "left_throw"
  else nil
  end
  bat_part = case batting
  when "right"  then "right_bat"
  when "left"   then "left_bat"
  when "switch" then "switch_hitter"
  else nil
  end
  return nil if throw_part.nil? || bat_part.nil?
  "#{throw_part}/#{bat_part}"
end

data_dir = ENV["CARD_DATA_DIR"].presence || Rails.root.join("db/import").to_s

card_set_defs = {
  "2025THBIG"   => { name: "2025THBIG",  year: 2025, set_type: "annual" },
  "hachinai6.1" => { name: "ハチナイ6.1", year: 2026, set_type: "hachinai61" },
  "PM2026"      => { name: "PM2026",     year: 2026, set_type: "pm2026" },
  "tamayomi2"   => { name: "球詠2",      year: 2026, set_type: "tamayomi2" }
}.freeze

# card_source → players.series の対応（外の世界枠判定に使用）
# PM2026はオリジナル選手枠（東方/ハチナイ/球詠の「外の世界」枠 = series:original）
CARD_SOURCE_SERIES = {
  "2025THBIG"   => "touhou",
  "hachinai6.1" => "hachinai",
  "tamayomi2"   => "tamayomi",
  "PM2026"      => "original"
}.freeze

player_card_map = {}
skipped_traits  = []

puts "=== Step 1: player_cards.csv ==="
CSV.foreach("#{data_dir}/player_cards.csv", headers: true) do |row|
  card_source = row["card_source"]
  defn = card_set_defs[card_source]
  unless defn
    puts "  WARN: unknown card_source '#{card_source}' (card_seq=#{row['card_seq']}), skipping"
    next
  end

  card_set = CardSet.find_or_create_by!(name: defn[:name]) do |cs|
    cs.year     = defn[:year]
    cs.set_type = defn[:set_type]
  end

  if row["name"].blank?
    puts "  WARN: card_seq=#{row['card_seq']} has blank name — skipped"
    next
  end
  required_stats = %w[speed bunt steal_start steal_end injury_rate]
  missing = required_stats.select { |f| row[f].blank? }
  if missing.any?
    puts "  WARN: card_seq=#{row['card_seq']} (#{row['name']}) missing #{missing.join(',')} — skipped"
    next
  end

  player_name = row["name"]
  normalized_name = player_name.gsub(/[\s\u3000]+/, '')
  player = Player.find_by("REPLACE(REPLACE(name, ' ', ''), '　', '') = ?", normalized_name) ||
           Player.create!(name: player_name, number: row["number"].presence || "?")

  # seriesが未設定の場合のみcard_sourceから補完（既存値を上書きしない）
  derived_series = CARD_SOURCE_SERIES[card_source]
  player.update_column(:series, derived_series) if player.series.nil? && derived_series.present?

  card_type = if row["card_type"].present?
                row["card_type"]
  elsif row["is_pitcher"] == "true"
                "pitcher"
  elsif row["is_pitcher"] == "false"
                "batter"
  end

  handedness_val = derive_handedness(row["throwing_hand"], row["batting_hand"])

  if row["irc_macro_name"].present?
    existing_by_macro = PlayerCard.where(card_set_id: card_set.id, irc_macro_name: row["irc_macro_name"], card_type: card_type)
                                  .where.not(player_id: player.id).first
    if existing_by_macro
      puts "  WARN: irc_macro_name=#{row['irc_macro_name']} (#{card_type}) already assigned to player=#{existing_by_macro.player&.name}(#{existing_by_macro.player_id}), skipping new record for #{player_name}"
      player_card_map[row["card_seq"]] = existing_by_macro
      next
    end
  end

  variant_val = row["variant"].presence

  pc = PlayerCard.find_or_create_by!(card_set_id: card_set.id, player_id: player.id, card_type: card_type, variant: variant_val) do |c|
    c.variant          = variant_val
    c.is_pitcher       = row["is_pitcher"] == "true"
    c.handedness       = handedness_val
    c.is_relief_only   = row["is_relief_only"] == "true"
    c.is_closer        = row["is_closer"] == "true"
    c.speed            = row["speed"].presence&.to_i
    c.bunt             = row["bunt"].presence&.to_i
    c.steal_start      = row["steal_start"].presence&.to_i
    c.steal_end        = row["steal_end"].presence&.to_i
    c.injury_rate      = row["injury_rate"].presence&.to_i
    c.starter_stamina  = row["starter_stamina"].presence&.to_i
    c.relief_stamina   = row["relief_stamina"].presence&.to_i
    c.unique_traits    = row["unique_traits"].presence
    c.biorhythm_period = row["biorhythm_period"].presence
    c.card_label       = row["card_label"].presence
    c.irc_macro_name   = row["irc_macro_name"].presence
    c.irc_display_name = row["irc_display_name"].presence

    if (raw = row["injury_traits"].presence)
      begin; c.injury_traits = JSON.parse(raw); rescue JSON::ParserError => e; Rails.logger.warn "JSON parse error: #{e.message}"; end
    end
    if (raw = row["biorhythm_date_ranges"].presence)
      begin; c.biorhythm_date_ranges = JSON.parse(raw); rescue JSON::ParserError => e; Rails.logger.warn "JSON parse error: #{e.message}"; end
    end
    if (raw = row["batting_table"].presence)
      begin; c.batting_table = JSON.parse(raw); rescue JSON::ParserError => e; Rails.logger.warn "JSON parse error: #{e.message}"; end
    end
    if (raw = row["pitching_table"].presence)
      begin; c.pitching_table = JSON.parse(raw); rescue JSON::ParserError => e; Rails.logger.warn "JSON parse error: #{e.message}"; end
    end
  end

  pc.update_column(:handedness, handedness_val) if pc.handedness.blank? && handedness_val.present?
  player_card_map[row["card_seq"]] = pc
end
puts "  PlayerCard.count = #{PlayerCard.count}"

puts "=== Step 2: player_card_defenses.csv ==="
CSV.foreach("#{data_dir}/player_card_defenses.csv", headers: true) do |row|
  pc = player_card_map[row["card_seq"]]
  next unless pc

  PlayerCardDefense.find_or_create_by!(
    player_card_id: pc.id,
    position:       row["position"],
    condition_id:   nil
  ) do |d|
    d.range_value = row["range_value"].to_i
    d.error_rank  = row["error_rank"]
    d.throwing    = row["throwing"].presence
  end
end
puts "  PlayerCardDefense.count = #{PlayerCardDefense.count}"

puts "=== Step 3: player_card_traits.csv ==="
CSV.foreach("#{data_dir}/player_card_traits.csv", headers: true) do |row|
  pc = player_card_map[row["card_seq"]]
  next unless pc

  trait_def = TraitDefinition.find_by(name: row["trait_definition_name"])
  unless trait_def
    skipped_traits << { card_seq: row["card_seq"], name: row["trait_definition_name"] }
    next
  end

  condition = TraitCondition.find_by(name: row["condition_name"].presence)

  PlayerCardTrait.find_or_create_by!(
    player_card_id:      pc.id,
    trait_definition_id: trait_def.id,
    condition_id:        condition&.id,
    role:                row["role"].presence
  ) do |t|
    t.sort_order = row["sort_order"].to_i
  end
end
puts "  PlayerCardTrait.count = #{PlayerCardTrait.count}"
if skipped_traits.any?
  puts "  Unresolved traits (#{skipped_traits.size}): #{skipped_traits.map { |s| s[:name] }.uniq.first(10).join(', ')}"
end

puts "=== Step 4: player_card_exclusive_catchers.csv ==="
CSV.foreach("#{data_dir}/player_card_exclusive_catchers.csv", headers: true) do |row|
  pc = player_card_map[row["card_seq"]]
  next unless pc

  catcher_name = row["catcher_name_raw"].presence
  next unless catcher_name

  catcher_player = Player.find_by(name: catcher_name)
  unless catcher_player
    puts "  WARN: catcher '#{catcher_name}' not found in players — skipped (import their card first)"
    next
  end

  PlayerCardExclusiveCatcher.find_or_create_by!(
    player_card_id:    pc.id,
    catcher_player_id: catcher_player.id
  )
end
puts "  PlayerCardExclusiveCatcher.count = #{PlayerCardExclusiveCatcher.count}"

puts "=== Card Import Done ==="
puts "CardSet.count              = #{CardSet.count}"
puts "Player.count               = #{Player.count}"
puts "PlayerCard.count           = #{PlayerCard.count}"
puts "PlayerCardDefense.count    = #{PlayerCardDefense.count}"
puts "PlayerCardTrait.count      = #{PlayerCardTrait.count}"
puts "PlayerCardExclusiveCatcher.count = #{PlayerCardExclusiveCatcher.count}"
