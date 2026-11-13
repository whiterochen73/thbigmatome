require "rails_helper"
require "rake"
require "csv"
require "json"

# PM2027 の取り込み（cmd_1893 / subtask_1893a）。rake（import:card_data）と seeds（db/seeds/import_cards.rb）の両方で確かめる。
#
# Test Basis:
#   - Operator 決定（2026-11-14）: 新たなカードセットとして PM2027 を足す。PM2026 は残す。set_type は「PM という系列が版を重ねる」作りを優先し、
#     外の世界判定は series（original）で見る
#   - タスク指示 手順 8: PlayerCard の PM2027 が 144、WARN・skip 行が 0 件、PM2026 の件数が不変、Player の増分は「PM2026 に居ない新しい選手」の数と一致
RSpec.describe "PM2027 の取り込み" do
  def rows = @rows ||= CSV.read(Rails.root.join("db/import/player_cards.csv"), headers: true)
  def norm(name) = name.to_s.gsub(/[\s　]+/, "")

  # 子表は CSV の語彙どおりに入ること（語彙に無い名前は WARN・skip になる）。出力から WARN と Unresolved の行を返す
  def run_with_output
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  shared_examples "PM2027 が入る" do
    it "PM2027 のカードセットは year 2027・set_type pm2027・series original で、PlayerCard が 144 枚" do
      set = CardSet.find_by(name: "PM2027")
      expect(set).to be_present
      expect(set.year).to eq(2027)
      expect(set.set_type).to eq("pm2027")
      expect(set.series).to eq("original")
      expect(PlayerCard.where(card_set: set).count).to eq(144)
    end

    it "PM2026 は 135 枚のまま、全体は 576 枚（取込から外れたカードは無い）" do
      expect(PlayerCard.where(card_set: CardSet.find_by(name: "PM2026")).count).to eq(135)
      expect(PlayerCard.count).to eq(576)
    end

    it "WARN・Unresolved の行が PM2027 のカードに 0 件（PM2027 の専属捕手は全員 Player に当たる）" do
      lines = @output.lines.grep(/WARN|Unresolved|skipped/).map(&:strip)
      pm27_seqs = rows.select { |r| r["card_source"] == "PM2027" }.map { |r| r["card_seq"] }
      expect(lines.select { |l| pm27_seqs.any? { |s| l.include?("card_seq=#{s} ") } }).to eq([])
      # 専属捕手の WARN は card_seq を出さない。残るのは PM2027 と無関係な既存の 1 件（2025THBIG の レティ）だけ
      expect(lines).to eq([ "WARN: catcher 'レティ' not found in players — skipped (import their card first)" ])
    end

    it "Player の数は、名前（空白を除く）の種類の数と一致する（PM2027 で増えるのは PM2026 までに居ない名前の分だけ）" do
      earlier = rows.select { |r| r["card_source"] != "PM2027" && r["name"].present? }.map { |r| norm(r["name"]) }.uniq
      all = rows.select { |r| r["name"].present? }.map { |r| norm(r["name"]) }.uniq
      # 追加 15 枚の持ち主はすべて既存の選手。増える 7 は、添え字つきの名前のカードのために importer が variant の付け替えより先に作る Player
      # （既存の挙動。PM2026 の添え字つきカードも同じ）。名前の表記ずれではない
      expect(all.size - earlier.size).to eq(7)
      expect(Player.count).to eq(all.size)
    end

    it "PM2027 のカードはすべて series original のセットに入り、持ち主の選手は series で original のカードを持つと判定される" do
      set = CardSet.find_by(name: "PM2027")
      players = Player.where(id: PlayerCard.where(card_set: set).select(:player_id))
      expect(players.count).to be > 100
      players.each { |pl| expect(pl.send(:has_original_series_card?)).to be(true), pl.name }
    end

    it "你 藍翠（PM2026 野手・PM2027 投手）と 冴月 麟（投手と野手が別カード）は二刀流のコスト種別を持たない" do
      ni = Player.find_by!(name: "你 藍翠")
      expect(ni.player_cards.map { |c| [ c.card_set.name, c.card_type ] }).to match_array([ %w[PM2026 batter], %w[PM2027 pitcher] ])
      expect(ni.available_cost_types).to eq([ "normal_cost" ])
      %w[冴月\ 麟\ (野手) 冴月\ 麟\ (投手)].each do |name|
        expect(Player.find_by!(name: name).available_cost_types).to eq([ "normal_cost" ]), name
      end
    end

    it "追加 15 枚の持ち主はすべて、PM2026 より前のセットにもカードを持つ選手（PM2027 だけの選手は居ない）。PM2027 だけの選手の判定は player_spec の工場データで確かめる" do
      added = JSON.parse(File.read(Rails.root.join("db/import/pm2027/pm2027_diff_summary.json")))["added"].map { |a| 433 + a["idx"] }
      set = CardSet.find_by(name: "PM2027")
      other_sets = CardSet.where.not(id: set.id).pluck(:id)
      rows.select { |r| added.include?(r["card_seq"].to_i) }.each do |r|
        base = (r["base_player_name"].presence || r["name"]).gsub(/[\s　]+/, "")
        pl = Player.find_by("REPLACE(REPLACE(name, ' ', ''), '　', '') = ?", base)
        expect(pl.player_cards.where(card_set_id: other_sets)).to exist, r["name"]
      end
    end
  end

  context "rake import:card_data" do
    before(:all) do
      Rails.application.load_tasks unless Rake::Task.task_defined?("import:card_data")
      ENV["CARD_DATA_DIR"] = Rails.root.join("db/import").to_s
      load Rails.root.join("db/seeds/master_traits.rb")
      Rake::Task["import:card_data"].reenable
      @output = run_with_output { Rake::Task["import:card_data"].invoke }
    end
    after(:all) do
      ENV.delete("CARD_DATA_DIR")
      DatabaseCleaner.clean_with(:truncation)
    end
    include_examples "PM2027 が入る"
  end

  context "db/seeds/import_cards.rb" do
    before(:all) do
      ENV["CARD_DATA_DIR"] = Rails.root.join("db/import").to_s
      load Rails.root.join("db/seeds/master_traits.rb")
      @output = run_with_output { load Rails.root.join("db/seeds/import_cards.rb") }
    end
    after(:all) do
      ENV.delete("CARD_DATA_DIR")
      DatabaseCleaner.clean_with(:truncation)
    end
    include_examples "PM2027 が入る"

    # rake は variant を使わない（添え字つきの別 Player に作る）ので、持ち主の付け替えがある seeds で確かめる
    it "専属捕手が入る（飯能の 八雲 紫 は 八雲 藍 と 橙、全越谷の 武田 詠深 は 山崎 珠姫）" do
      set = CardSet.find_by(name: "PM2027")
      pc = PlayerCard.find_by(card_set: set, variant: "飯能")
      expect(pc.player.name).to eq("八雲 紫")
      expect(pc.player_card_exclusive_catchers.map { |c| c.catcher_player.name }).to match_array([ "八雲 藍", "橙" ])
      tama = PlayerCard.find_by(card_set: set, variant: "全越谷", player: Player.find_by(name: "武田 詠深"))
      expect(tama.player_card_exclusive_catchers.map { |c| c.catcher_player.name }).to eq([ "山崎 珠姫" ])
    end
  end
end
