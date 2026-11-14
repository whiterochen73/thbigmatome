# db/seeds/import_cards.rb
# 選手カードデータをCSVからインポートする（import:card_data rakeタスクと同じ実装 = lib/card_importer.rb）
# CSVソース: db/import/ ディレクトリ（CARD_DATA_DIR で変更可）。DRY_RUN=1・REPORT_PATH=<csv> も rake と同じ。
CardImporter.new(
  data_dir: ENV["CARD_DATA_DIR"].presence || Rails.root.join("db/import").to_s,
  dry_run: ENV["DRY_RUN"] == "1",
  report_path: ENV["REPORT_PATH"]
).run
