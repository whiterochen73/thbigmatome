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

# card_source → カードセットの定義（名前・年・set_type・series・現行の印）は config/card_set_definitions.yml が正本。rake import:card_data と共通。
# PM2028 が出た時は、そこに足して PM2027 の current を false にするだけでよい。
card_set_defs = CardSet::IMPORT_DEFINITIONS

player_card_map = {}
skipped_traits  = []

# 同じカードセット・種別で irc_macro_name（=背番号）が複数のカードに共通する組は、別人のカードが同じ番号を持つだけ（PM2026 の 9・10・00 など）。
# 下の「別 player に同じ macro」の重複防止はその組には当てはめない（当てはめると正規の別カードが取込から外れる）。
shared_macro_keys = CSV.read("#{data_dir}/player_cards.csv", headers: true)
                       .group_by { |r| [ r["card_source"], r["irc_macro_name"].presence, r["card_type"].presence || (r["is_pitcher"] == "true" ? "pitcher" : "batter") ] }
                       .select { |k, v| k[1] && v.size > 1 }.keys

puts "=== Step 1: player_cards.csv ==="
CSV.foreach("#{data_dir}/player_cards.csv", headers: true) do |row|
  card_source = row["card_source"]
  defn = card_set_defs[card_source]
  unless defn
    puts "  WARN: unknown card_source '#{card_source}' (card_seq=#{row['card_seq']}), skipping"
    next
  end

  card_set = CardSet.find_or_create_by!(name: defn[:name]) do |cs|
    cs.year       = defn[:year]
    cs.set_type   = defn[:set_type]
    cs.series     = defn[:series]
    cs.is_current = defn[:current]
  end
  # 現行の印は対応表に合わせる（既存のカードセットにも効く。PM2028 の時に PM2027 を外すため）
  card_set.update_column(:is_current, defn[:current]) if card_set.is_current != defn[:current]

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
  derived_series = defn[:series]
  player.update_column(:series, derived_series) if player.series.nil? && derived_series.present?

  # バリエーション処理: variant列があればベースプレイヤーに player_id を付け替える
  # base_player_name が空の場合は player_id 変更なし（冴月麟など）
  variant_val = row["variant"].presence
  base_player_name = row["base_player_name"].presence
  if variant_val.present? && base_player_name.present?
    normalized_base = base_player_name.gsub(/[\s\u3000]+/, '')
    base_player = Player.find_by("REPLACE(REPLACE(name, ' ', ''), '　', '') = ?", normalized_base)
    if base_player
      player = base_player
    else
      puts "  WARN: base_player_name='#{base_player_name}' not found for #{player_name}, using variant player"
    end
  end

  card_type = if row["card_type"].present?
                row["card_type"]
  elsif row["is_pitcher"] == "true"
                "pitcher"
  elsif row["is_pitcher"] == "false"
                "batter"
  end

  handedness_val = derive_handedness(row["throwing_hand"], row["batting_hand"])

  if row["irc_macro_name"].present? && !shared_macro_keys.include?([ card_source, row["irc_macro_name"], card_type ])
    existing_by_macro = PlayerCard.where(card_set_id: card_set.id, irc_macro_name: row["irc_macro_name"], card_type: card_type)
                                  .where.not(player_id: player.id).first
    if existing_by_macro
      puts "  WARN: irc_macro_name=#{row['irc_macro_name']} (#{card_type}) already assigned to player=#{existing_by_macro.player&.name}(#{existing_by_macro.player_id}), skipping new record for #{player_name}"
      player_card_map[row["card_seq"]] = existing_by_macro
      next
    end
  end

  find_key = { card_set_id: card_set.id, player_id: player.id, card_type: card_type }
  find_key[:variant] = variant_val if variant_val.present?
  pc = PlayerCard.find_or_create_by!(**find_key) do |c|
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
    c.official_use_prohibited = row["official_use_prohibited"] == "true"

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
  # 公式戦で使用できない印は CSV（画像の注記）に従う。既存 DB の行にも反映する
  pc.update_column(:official_use_prohibited, true) if row["official_use_prohibited"] == "true" && !pc.official_use_prohibited
  player_card_map[row["card_seq"]] = pc
end
puts "  PlayerCard.count = #{PlayerCard.count}"

puts "=== Step 2: player_card_defenses.csv ==="
CSV.foreach("#{data_dir}/player_card_defenses.csv", headers: true) do |row|
  pc = player_card_map[row["card_seq"]]
  next unless pc

  # 条件付きの守備（登板時の捕手など）は condition_name で持つ。語彙に無い名前は黙って通常の行にせず飛ばす
  condition = nil
  if row["condition_name"].present?
    condition = TraitCondition.find_by(name: row["condition_name"])
    unless condition
      puts "  WARN: card_seq=#{row['card_seq']} defense condition '#{row['condition_name']}' not found — skipped"
      next
    end
  end

  PlayerCardDefense.find_or_create_by!(
    player_card_id: pc.id,
    position:       row["position"],
    condition_id:   condition&.id
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

  catcher_player = Player.find_by(name: catcher_name) ||
                   Player.find_by("REPLACE(REPLACE(name, ' ', ''), '　', '') = ?", catcher_name.gsub(/[\s\u3000]+/, ""))
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

puts "=== Step 5: player_card_abilities.csv ==="
CSV.foreach("#{data_dir}/player_card_abilities.csv", headers: true) do |row|
  pc = player_card_map[row["card_seq"]]
  next unless pc

  ability_def = AbilityDefinition.find_by(name: row["ability_definition_name"])
  unless ability_def
    puts "  WARN: card_seq=#{row['card_seq']} ability '#{row['ability_definition_name']}' not found in ability_definitions — skipped (seed master_traits first)"
    next
  end

  condition = TraitCondition.find_by(name: row["condition_name"].presence)

  PlayerCardAbility.find_or_create_by!(
    player_card_id:        pc.id,
    ability_definition_id: ability_def.id,
    condition_id:          condition&.id,
    role:                  row["role"].presence
  ) do |a|
    a.sort_order = row["sort_order"].to_i
  end
end
puts "  PlayerCardAbility.count = #{PlayerCardAbility.count}"

puts "=== Card Import Done ==="
puts "CardSet.count              = #{CardSet.count}"
puts "Player.count               = #{Player.count}"
puts "PlayerCard.count           = #{PlayerCard.count}"
puts "PlayerCardDefense.count    = #{PlayerCardDefense.count}"
puts "PlayerCardTrait.count      = #{PlayerCardTrait.count}"
puts "PlayerCardExclusiveCatcher.count = #{PlayerCardExclusiveCatcher.count}"
