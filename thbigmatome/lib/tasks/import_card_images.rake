require "csv"

namespace :import do
  desc "Attach trimmed card images to PlayerCard via Active Storage (idempotent)"
  task card_images: :environment do
    PlayerCardLocator.clear_cache!
    base_dir   = ENV.fetch("CARD_IMAGE_DIR",
                           "/mnt/c/tools/multi-agent-shogun/projects/thbig/context/thbig-irc-cards/split/")
    # 既定は取り込みと同じ db/import/player_cards.csv（card_seq の並び・variant・base_player_name が取り込みと一致する）
    csv_path   = ENV.fetch("CARD_CSV_PATH", Rails.root.join("db/import/player_cards.csv").to_s)
    cards_per_page = 9

    # Directory name -> CardSet.name in DB
    card_set_defs = {
      "2025THBIG"   => "2025THBIG",
      "hachinai6.1" => "ハチナイ6.1",
      "PM2026"      => "PM2026",
      "PM2027"      => "PM2027",
      "tamayomi2"   => "球詠2"
    }.freeze

    # Load CSV: card_seq (int) => CSV の行（カードの当て先は PlayerCardLocator が取り込みと同じ引き方で決める）
    seq_map   = {}
    base_seqs = {}  # card_source -> minimum card_seq in CSV

    CSV.foreach(csv_path, headers: true) do |row|
      seq = row["card_seq"].to_i
      src = row["card_source"]
      seq_map[seq] = row
      base_seqs[src] = [base_seqs.fetch(src, seq), seq].min
    end
    puts "Loaded #{seq_map.size} rows from CSV"

    total_attached = 0
    total_skipped  = 0
    total_not_found = 0

    card_set_defs.each do |dir_name, card_set_name|
      trimmed_dir = File.join(base_dir, dir_name, "trimmed")

      unless Dir.exist?(trimmed_dir)
        puts "WARN: #{trimmed_dir} not found, skipping"
        next
      end

      card_set = CardSet.find_by(name: card_set_name)
      unless card_set
        puts "WARN: CardSet '#{card_set_name}' not in DB, skipping"
        next
      end

      base_seq = base_seqs[dir_name]
      unless base_seq
        puts "WARN: no CSV rows for '#{dir_name}', skipping"
        next
      end

      puts "=== #{dir_name} (CardSet: #{card_set_name}, base_seq: #{base_seq}) ==="

      pngs = Dir.glob(File.join(trimmed_dir, "p*_c*.png")).sort_by do |f|
        m = File.basename(f).match(/p(\d+)_c(\d+)/)
        [m[1].to_i, m[2].to_i]
      end

      pngs.each do |path|
        m = File.basename(path).match(/p(\d+)_c(\d+)/)
        next unless m

        page_idx = m[1].to_i - 1  # 0-indexed
        col      = m[2].to_i       # 1-indexed (1-9)
        card_seq = base_seq + (page_idx * cards_per_page) + (col - 1)

        entry = seq_map[card_seq]
        unless entry
          puts "  WARN: no CSV entry for card_seq=#{card_seq} (#{File.basename(path)})"
          total_not_found += 1
          next
        end

        player_name = entry["name"]
        located = PlayerCardLocator.locate(entry)
        pc = located.card
        unless pc
          puts "  SKIP: PlayerCard not found (#{located.reason}): '#{player_name}' / #{card_set_name} / #{entry['card_type']} (card_seq=#{card_seq})"
          total_skipped += 1
          next
        end

        if pc.card_image.attached?
          total_skipped += 1
          next
        end

        File.open(path, 'rb') do |f|
          pc.card_image.attach(
            io:           f,
            filename:     File.basename(path),
            content_type: "image/png"
          )
        end
        total_attached += 1
        puts "  Attached: #{player_name} <- #{File.basename(path)}" if total_attached <= 5 || (total_attached % 50).zero?
      end

      attached_in_set = PlayerCard.where(card_set: card_set).joins(:card_image_attachment).count
      puts "  #{dir_name}: #{attached_in_set} / #{PlayerCard.where(card_set: card_set).count} cards have image"
    end

    puts ""
    puts "=== Summary ==="
    puts "Attached:   #{total_attached}"
    puts "Skipped:    #{total_skipped} (already attached or not in DB)"
    puts "Not found:  #{total_not_found} (no CSV entry for card_seq)"
    puts "Total PlayerCard with image: #{PlayerCard.joins(:card_image_attachment).count}"
  end

  desc "Match every player_cards.csv row to a PlayerCard the way the card images would (no image files needed; reads DB only). CARD_CSV_PATH, OUT=<csv> for details"
  task card_image_targets: :environment do
    PlayerCardLocator.clear_cache!
    csv_path = ENV.fetch("CARD_CSV_PATH", Rails.root.join("db/import/player_cards.csv").to_s)
    result = PlayerCardLocator.audit(CSV.read(csv_path, headers: true))
    puts "rows=#{result[:total]} matched=#{result[:found]} missing=#{result[:missing].size} mismatched=#{result[:mismatched].size} collisions=#{result[:collisions].size}"
    result[:missing].each { |m| puts "MISSING card_seq=#{m[:card_seq]} #{m[:card_source]} #{m[:name]} (#{m[:reason]})" }
    result[:mismatched].each { |m| puts "MISMATCH card_seq=#{m[:card_seq]} #{m[:card_source]} #{m[:name]} card_id=#{m[:card_id]} fields=#{m[:fields].join('/')}" }
    result[:collisions].each { |c| puts "COLLISION card_id=#{c[:card_id]} card_seqs=#{c[:card_seqs].join(',')}" }
    if ENV["OUT"].present?
      CSV.open(ENV["OUT"], "w") do |csv|
        csv << %w[kind card_seq card_source name card_id detail]
        result[:missing].each { |m| csv << [ "missing", m[:card_seq], m[:card_source], m[:name], nil, m[:reason] ] }
        result[:mismatched].each { |m| csv << [ "mismatched", m[:card_seq], m[:card_source], m[:name], m[:card_id], m[:fields].join("/") ] }
        result[:collisions].each { |c| csv << [ "collision", c[:card_seqs].join(","), nil, nil, c[:card_id], nil ] }
      end
    end
  end
end
