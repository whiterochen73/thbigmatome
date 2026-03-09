require "csv"

namespace :import do
  desc "Import card data from CSV files into DB (idempotent)"
  task card_data: :environment do
    def derive_handedness(throwing, batting)
      throw_part = case throwing
                   when "right" then "右投"
                   when "left"  then "左投"
                   else ""
                   end
      bat_part = case batting
                 when "right"  then "右打"
                 when "left"   then "左打"
                 when "switch" then "両打"
                 else ""
                 end
      result = throw_part + bat_part
      result.empty? ? nil : result
    end
    data_dir = ENV["CARD_DATA_DIR"] || "/home/morinaga/projects/thbig-irc-parser/data/import"

    card_set_defs = {
      "2025THBIG"   => { name: "2025THBIG",  year: 2025, set_type: "annual" },
      "hachinai6.1" => { name: "ハチナイ6.1", year: 2026, set_type: "hachinai61" },
      "PM2026"      => { name: "PM2026",     year: 2026, set_type: "pm2026" },
      "tamayomi2"   => { name: "球詠2",      year: 2026, set_type: "tamayomi2" }
    }.freeze

    # card_seq => PlayerCard (for association building)
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

      # CardSet
      card_set = CardSet.find_or_create_by!(name: defn[:name]) do |cs|
        cs.year     = defn[:year]
        cs.set_type = defn[:set_type]
      end

      # Required fields check (name + stats required for Player and PlayerCard)
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

      # Player
      player_name = row["name"]
      player = Player.find_or_create_by!(name: player_name) do |p|
        p.number = row["number"].presence || "?"
      end

      # Derive card_type from is_pitcher (CSV) or card_type column if available
      card_type = if row["card_type"].present?
                    row["card_type"]
                  elsif row["is_pitcher"] == "true"
                    "pitcher"
                  elsif row["is_pitcher"] == "false"
                    "batter"
                  end

      handedness_val = derive_handedness(row["throwing_hand"], row["batting_hand"])

      # PlayerCard
      pc = PlayerCard.find_or_create_by!(card_set_id: card_set.id, player_id: player.id, card_type: card_type) do |c|
        c.is_pitcher    = row["is_pitcher"] == "true"
        c.handedness    = handedness_val
        c.is_relief_only = row["is_relief_only"] == "true"
        c.is_closer     = row["is_closer"] == "true"
        c.speed         = row["speed"].presence&.to_i
        c.bunt          = row["bunt"].presence&.to_i
        c.steal_start   = row["steal_start"].presence&.to_i
        c.steal_end     = row["steal_end"].presence&.to_i
        c.injury_rate   = row["injury_rate"].presence&.to_i
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

      # 既存レコードの handedness が未設定の場合は更新
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

    puts "=== Done ==="
    puts "CardSet.count              = #{CardSet.count}"
    puts "Player.count               = #{Player.count}"
    puts "PlayerCard.count           = #{PlayerCard.count}"
    puts "PlayerCardDefense.count    = #{PlayerCardDefense.count}"
    puts "PlayerCardTrait.count      = #{PlayerCardTrait.count}"
    puts "PlayerCardExclusiveCatcher.count = #{PlayerCardExclusiveCatcher.count}"
  end
end
