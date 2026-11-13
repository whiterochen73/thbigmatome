require "rails_helper"
require "rake"
require "csv"
require "json"

# 全カード取り込み（cmd_1891）。公式戦で使用できないカード 23 枚の印と、名前が空で取込から外れていた横綱 3 枚の取り込み。
#
# Test Basis:
#   - Operator 決定（2026-11-13）: 「カードを全部取り込む方針に変更する」。DB 登録対象外の旧方針を撤回
#   - context/thbig-card-data-reread-all.md §2.2（名前が空の 3 枚）・§2.12（注記「※公式戦で使用できません。」の 23 枚）
#   - 値の出どころ: db/import/reread/card_reread_2026-11-13.json（名前の付記は画像で確認: 331・332・339 は付記なし）
RSpec.describe "import:card_data（公式戦使用不可の印・全 432 枚取り込み）" do
  PROHIBITED_SEQS = [ 331, 332, 333, 338, 339, 340, 341, 342, 359, 360, 385, 400, 401, 402, 406,
                      407, 408, 409, 410, 411, 412, 413, 414 ].freeze
  YOKOZUNA = { 331 => [ "特例 ちゃん", "25", "横綱" ], 332 => [ "カナック", "77", "横綱" ], 339 => [ "自分 勝手", "15", "大関" ] }.freeze

  let(:data_dir) { Rails.root.join("db/import").to_s }
  let(:set_names) { { "2025THBIG" => "2025THBIG", "hachinai6.1" => "ハチナイ6.1", "PM2026" => "PM2026", "PM2027" => "PM2027", "tamayomi2" => "球詠2" } }

  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("import:card_data")
    ENV["CARD_DATA_DIR"] = Rails.root.join("db/import").to_s
    Rake::Task["import:card_data"].reenable
    load Rails.root.join("db/seeds/master_traits.rb")
    original_stdout = $stdout
    $stdout = StringIO.new
    begin
      Rake::Task["import:card_data"].invoke
    ensure
      $stdout = original_stdout
    end
  end

  after(:all) do
    ENV.delete("CARD_DATA_DIR")
    DatabaseCleaner.clean_with(:truncation)
  end

  # この spec は 432 枚（PM2026 まで。cmd_1891）の取込を確かめる。PM2027（cmd_1893）の 144 枚は import_pm2027_spec が数える
  def rows = @rows ||= CSV.read(File.join(data_dir, "player_cards.csv"), headers: true).reject { |r| r["card_source"] == "PM2027" }
  def legacy_cards = PlayerCard.where.not(card_set_id: CardSet.where(name: "PM2027").select(:id))
  def row_of(seq) = rows.find { |r| r["card_seq"] == seq.to_s }

  def db_card(seq)
    row = row_of(seq)
    player = Player.find_by("REPLACE(REPLACE(name, ' ', ''), '　', '') = ?", row["name"].gsub(/[\s　]+/, ""))
    PlayerCard.find_by(player_id: player&.id, card_set_id: CardSet.find_by(name: set_names[row["card_source"]])&.id,
                       card_type: row["card_type"])
  end

  describe "全カード取り込み" do
    it "CSV は 432 枚で、名前・位置・番号が空のカードは 0 枚" do
      expect(rows.size).to eq(432)
      expect(rows.select { |r| r["name"].blank? || r["number"].blank? || r["position"].blank? }.map { |r| r["card_seq"] }).to eq([])
    end

    it "432 枚すべてが DB に入る（これまで飛ばされていた 331・332・339 を含む。旧期待値 429）" do
      expect(legacy_cards.count).to eq(432)
      expect(rows.map { |r| db_card(r["card_seq"]) }.compact.size).to eq(432)
    end

    it "331・332・339 は画像で確かめた名前・番号・位置で CSV に入り、parse_status は ok" do
      YOKOZUNA.each do |seq, (name, number, position)|
        r = row_of(seq)
        expect([ r["name"], r["number"], r["position"], r["parse_status"] ]).to eq([ name, number, position, "ok" ])
        expect(r["irc_macro_name"]).to eq(number)
        expect(db_card(seq).player.name).to eq(name)
        expect(db_card(seq).player.number).to eq(number)
      end
    end

    it "同名・同種別の別カードは印字の付記で区別され、付記が無い 385 だけ「(2)」（取込の鍵で潰れない）" do
      # 付記の順: 人物の別名なら印字の付記 → 球団名なら球団名 → 付記が無い時だけ (2)。349・357 の印字は（エイプリル）、396 は（最上川）
      { 349 => [ 342, "魂魄 妖夢 (エイプリル)", "魂魄 妖夢" ], 357 => [ 396, "永江 衣玖 (エイプリル)", "永江 衣玖 (最上川)" ],
        385 => [ 326, "坂田 ネムノ (2)", "坂田 ネムノ" ] }.each do |seq, (other_seq, name, other_name)|
        expect(row_of(seq)["name"]).to eq(name)
        expect(row_of(other_seq)["name"]).to eq(other_name)
        expect(db_card(seq).id).not_to eq(db_card(other_seq).id)
      end
      expect([ row_of(349)["variant"], row_of(357)["variant"], row_of(396)["variant"] ]).to eq(%w[エイプリル エイプリル 最上川])
    end

    it "variant の付いた行は base_player_name（同じ人物の名前）を保つ。385 だけ 326 と同じ variant（安曇野）のため空" do
      expect(%w[349 357 396].map { |q| row_of(q)["base_player_name"] }).to eq(%w[魂魄\ 妖夢 永江\ 衣玖 永江\ 衣玖])
      expect([ row_of(326)["variant"], row_of(385)["variant"], row_of(385)["base_player_name"].presence ]).to eq([ "安曇野", "安曇野", nil ])
      keys = rows.map { |r| [ r["card_source"], (r["base_player_name"].presence || r["name"]).gsub(/[\s　]+/, ""), r["card_type"], r["variant"] ] }
      expect(keys.uniq.size).to eq(432)
    end

    it "同じ組・種別で背番号（irc_macro_name）が共通する別人のカードは重複扱いで落とさない（PM2026 の 9・00・10）" do
      %w[西行寺\ 幽々子(楼閣) 八雲\ 藍\ (WBC2) 花山\ 栄美 小鳥遊\ 柚].each do |name|
        r = rows.find { |x| x["card_source"] == "PM2026" && x["name"] == name }
        expect(r).to be_present, name
        expect(db_card(r["card_seq"])).to be_present, name
      end
    end

    it "3 枚の防御・特徴が取り込まれる" do
      expect(db_card(332).player_card_defenses.pluck(:position, :range_value, :error_rank, :throwing)).to eq([ [ "C", 3, "E", "-1" ] ])
      expect(db_card(331).player_card_traits.count).to be >= 1
    end
  end

  describe "official_use_prohibited（公式戦で使用できない）" do
    it "既定値は false（NOT NULL）" do
      col = PlayerCard.columns_hash["official_use_prohibited"]
      expect(col).to be_present
      expect(col.null).to be(false)
      expect(PlayerCard.new.official_use_prohibited).to be(false)
    end

    it "CSV で true なのは指定の 23 枚だけ、ほかの 409 枚は false" do
      expect(rows.first.headers).to include("official_use_prohibited")
      expect(rows.select { |r| r["official_use_prohibited"] == "true" }.map { |r| r["card_seq"].to_i }.sort).to eq(PROHIBITED_SEQS)
      expect(rows.reject { |r| r["official_use_prohibited"] == "true" }.map { |r| r["official_use_prohibited"] }.uniq).to eq([ "false" ])
    end

    it "取り込み後、印は 23 枚の DB 行にだけ付く" do
      expect(legacy_cards.where(official_use_prohibited: true).count).to eq(23)
      flagged = PROHIBITED_SEQS.map { |s| db_card(s) }
      expect(flagged.compact.size).to eq(23)
      expect(flagged.map(&:official_use_prohibited)).to all(be(true))
      expect(legacy_cards.where.not(id: flagged.map(&:id)).where(official_use_prohibited: true)).to be_empty
    end

    it "API のカード詳細にも載る" do
      json = PlayerCardDetailSerializer.new(db_card(331)).as_json
      expect(json[:official_use_prohibited]).to be(true)
      expect(PlayerCardDetailSerializer.new(db_card(1)).as_json[:official_use_prohibited]).to be(false)
    end
  end
end
