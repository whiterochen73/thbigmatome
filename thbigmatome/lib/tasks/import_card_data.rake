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
    # JSON の中の参照（過去の記録が選手の id か名前を JSON に持つ）。列を見るかどうかは schema の json/jsonb 列を総なめにし、
    # 選手を持たないと分かっている列だけを除く（新しい列は既定で見る側に倒す）。id は選手系キー配下の整数、名前は文字列の一致（部分一致でも消さない側）
    json_skip = %w[player_cards.batting_table player_cards.pitching_table player_cards.injury_traits player_cards.biorhythm_date_ranges
                   competitions.rules stadiums.up_table_ids squad_text_settings.batting_stats_config squad_text_settings.pitching_stats_config at_bats.rolls]
    json_cols = conn.tables.flat_map do |t|
      conn.columns(t).select { |col| %i[json jsonb].include?(col.type) }.map { |col| [ t, col.name ] }
    end.reject { |t, c| json_skip.include?("#{t}.#{c}") }
    puts "JSON 列（見る）: #{json_cols.map { |t, c| "#{t}.#{c}" }.join(', ')}"
    puts "JSON 列（見ない・選手を持たない）: #{json_skip.join(', ')}"
    # JSON をパースし、キー名が選手系のもの（単数・複数・_id・_ids を問わない）の配下の整数を、配列・入れ子まで再帰で集める。
    # 選手系キーの配下では、キーが id 系（id / *_id / *_ids）か選手系の整数と、整数だけの配列の要素を拾う（batting_order など無関係な数値は拾わない）。
    # 迷う形は「使われている」側に倒す（取りすぎは安全）。パースできない JSON は数字の羅列を全部拾う
    player_key = /player|batter|pitcher|runner|catcher|fielder|hitter|starter|bench|relief|closer|lineup|member|roster|off_/i
    id_like = /(\A|_)ids?\z/i
    to_id = ->(v) { v.is_a?(Integer) ? v : (v.is_a?(String) && v.match?(/\A\d+\z/) ? v.to_i : nil) }
    collect = nil
    collect = lambda do |node, ctx, out|
      case node
      when Hash
        node.each do |k, v|
          k = k.to_s
          kctx = ctx || k.match?(player_key)
          id = to_id.call(v)
          out << id if id && kctx && (k.match?(id_like) || k.match?(player_key))
          collect.call(v, kctx, out)
        end
      when Array
        node.each do |v|
          id = to_id.call(v)
          out << id if id && ctx
          collect.call(v, ctx, out) unless id
        end
      end
    end
    json_ids = Set.new
    json_texts = []
    json_cols.each do |t, c|
      q = "#{conn.quote_table_name(t)}.#{conn.quote_column_name(c)}"
      conn.select_values("SELECT #{q}::text FROM #{conn.quote_table_name(t)} WHERE #{q} IS NOT NULL AND #{q}::text NOT IN ('{}', '[]', 'null')").each do |txt|
        begin
          collect.call(JSON.parse(txt), false, json_ids)
        rescue JSON::ParserError
          txt.scan(/\d+/) { |m| json_ids << m.to_i }
        end
        json_texts << txt
      end
    end
    json_blob = json_texts.join("\n")
    in_json = unreferenced.select { |p| json_ids.include?(p.id) || (p.name.present? && json_blob.include?(p.name)) }
    puts "JSON の中に出てくる Player: #{in_json.size} 人（消さない）#{in_json.map { |p| "##{p.id} #{p.name}" }.join(', ')}"
    unreferenced -= in_json
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
