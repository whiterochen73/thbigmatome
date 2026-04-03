require "csv"

namespace :import do
  desc "Attach trimmed card images to PlayerCard via Active Storage (idempotent)"
  task card_images: :environment do
    base_dir   = ENV.fetch("CARD_IMAGE_DIR",
                           "/mnt/c/tools/multi-agent-shogun/projects/thbig/context/thbig-irc-cards/split/")
    csv_path   = ENV.fetch("CARD_CSV_PATH",
                           "/home/morinaga/projects/thbig-irc-parser/data/import/player_cards.csv")
    cards_per_page = 9

    # Directory name -> CardSet.name in DB
    card_set_defs = {
      "2025THBIG"   => "2025THBIG",
      "hachinai6.1" => "ハチナイ6.1",
      "PM2026"      => "PM2026",
      "tamayomi2"   => "球詠2"
    }.freeze

    # Load CSV: card_seq (int) => { name:, card_source: }
    seq_map   = {}
    base_seqs = {}  # card_source -> minimum card_seq in CSV

    CSV.foreach(csv_path, headers: true) do |row|
      seq = row["card_seq"].to_i
      src = row["card_source"]
      seq_map[seq] = { name: row["name"], card_source: src, card_type: row["card_type"] }
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

        player_name = entry[:name]
        player = Player.find_by(name: player_name)
        unless player
          puts "  SKIP: player '#{player_name}' not in DB (card_seq=#{card_seq})"
          total_skipped += 1
          next
        end

        card_type = entry[:card_type]
        pc = PlayerCard.find_by(card_set: card_set, player: player, card_type: card_type)
        unless pc
          puts "  SKIP: PlayerCard not found: '#{player_name}' / #{card_set_name} / #{card_type} (card_seq=#{card_seq})"
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
end
