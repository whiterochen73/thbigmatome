namespace :rules do
  desc "game_rules.yaml のバージョンを直近の sync-rules 実行時バージョンと照合する"
  task check: :environment do
    require "yaml"

    local_path   = Rails.root.join("config", "game_rules.yaml")
    synced_version_path = Rails.root.join("config", ".game_rules_synced_version")

    unless File.exist?(local_path)
      warn "WARN: config/game_rules.yaml が見つかりません"
      exit 1
    end

    local         = YAML.load_file(local_path)
    local_version = local["version"]

    if File.exist?(synced_version_path)
      synced_version = File.read(synced_version_path).strip
      if local_version == synced_version
        puts "OK: game_rules.yaml v#{local_version} — sync-rules と一致しています"
      else
        warn "WARN: バージョン不一致"
        warn "  ローカル       : v#{local_version} (config/game_rules.yaml)"
        warn "  最終sync時     : v#{synced_version} (config/.game_rules_synced_version)"
        warn "  make sync-rules を実行してバージョンを合わせてください"
      end
    else
      puts "INFO: config/game_rules.yaml v#{local_version} — .game_rules_synced_version が未作成"
      puts "      (make sync-rules を一度実行してください)"
    end
  end
end
