require "csv"

namespace :import do
  desc "Import card data from CSV files into DB (idempotent). CARD_DATA_DIR（既定 db/import）・DRY_RUN=1・REPORT_PATH=<csv>"
  task card_data: :environment do
    # 実処理は lib/card_importer.rb（db/seeds/import_cards.rb と共通）。
    # カードの鍵は card_seq。旧行は最初の 1 回だけ照合して card_seq を書き込む。DRY_RUN=1 は transaction を rollback し、REPORT_PATH にどの旧行をどう変えたかの CSV を出す
    CardImporter.new(
      data_dir: ENV["CARD_DATA_DIR"].presence || Rails.root.join("db/import").to_s,
      dry_run: ENV["DRY_RUN"] == "1",
      report_path: ENV["REPORT_PATH"]
    ).run
  end

  desc "カードも在籍も参照も無い Player を一覧する（既定は dry-run）。APPLY=1 で削除。1 件ずつ参照元を確かめてから消す"
  task orphan_players: :environment do
    apply = ENV["APPLY"] == "1"
    conn = ActiveRecord::Base.connection
    # players を指す列: FK のある列と、名前が *player_id の列（FK が無くても参照とみなす）
    refs = []
    conn.tables.each do |t|
      next if t == "players"
      fk_cols = conn.foreign_keys(t).select { |fk| fk.to_table == "players" }.map(&:column)
      cols = conn.columns(t).map(&:name).select { |c| c.end_with?("player_id") }
      (fk_cols + cols).uniq.each { |c| refs << [ t, c ] }
    end
    puts "players を指す列: #{refs.map { |t, c| "#{t}.#{c}" }.join(', ')}"
    unreferenced = Player.order(:id).select do |p|
      refs.none? { |t, c| conn.select_value("SELECT 1 FROM #{conn.quote_table_name(t)} WHERE #{conn.quote_column_name(c)} = #{p.id.to_i} LIMIT 1") }
    end
    puts "#{apply ? 'DELETE' : 'DRY-RUN'}: 参照の無い Player #{unreferenced.size} 人"
    unreferenced.each { |p| puts "  ##{p.id} #{p.name}" }
    if apply
      Player.transaction { unreferenced.each(&:destroy!) }
      puts "削除した: #{unreferenced.size} 人"
    else
      puts "削除するには APPLY=1 を付ける"
    end
  end
end
