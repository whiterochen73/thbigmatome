require "rails_helper"
require "rake"
require "csv"
require "json"

# 432 枚の画像読み直し照合（cmd_1887）のうち、今の表の作りのまま直せる (A) を、実データ（db/import/*.csv）を
# import:card_data に通して確かめる。
#
# Test Basis:
#   - context/thbig-card-data-reread-all.md §2.1〜2.9・§3.2（A1〜A7）
#   - 読み直しの正（核）: db/import/reread/card_reread_2026-11-13.json（README 参照）
#   - 本体判断（subtask_1888a）: 324・375 は野手カードのまま投球表と疲労 P を持つ。394・421 は投手カード
# 「画像」は読み直しの核。card_seq は同文書の表の番号。
RSpec.describe "import:card_data（読み直し照合 A1〜A7・実データ）" do
  let(:data_dir) { Rails.root.join("db/import").to_s }
  let(:set_names) { { "2025THBIG" => "2025THBIG", "hachinai6.1" => "ハチナイ6.1", "PM2026" => "PM2026", "tamayomi2" => "球詠2" } }

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

  # この spec は 432 枚（PM2026 まで。cmd_1887・1888）の読み直し核との照合。card_seq 433 以降は PM2027（cmd_1893）で核が無い
  def csv_rows(file) = CSV.read(File.join(data_dir, file), headers: true).select { |r| r["card_seq"].to_i <= 432 }
  def core = @core ||= JSON.parse(File.read(File.join(data_dir, "reread/card_reread_2026-11-13.json")))
  def card_row(seq) = csv_rows("player_cards.csv").find { |r| r["card_seq"] == seq.to_s }

  def db_card(seq)
    row = card_row(seq)
    player = Player.find_by("REPLACE(REPLACE(name, ' ', ''), '　', '') = ?", row["name"].gsub(/[\s　]+/, ""))
    PlayerCard.find_by(player_id: player&.id,
                       card_set_id: CardSet.find_by(name: set_names[row["card_source"]])&.id,
                       card_type: row["card_type"])
  end

  def traits_of(seq)
    db_card(seq).player_card_traits.includes(:trait_definition, :condition).order(:sort_order, :id)
                .map { |t| [ t.trait_definition.name, t.condition&.name, t.role ] }
  end

  HANDEDNESS = {
    %w[right right] => "right_throw/right_bat", %w[right left] => "right_throw/left_bat",
    %w[right switch] => "right_throw/switch_hitter", %w[left left] => "left_throw/left_bat",
    %w[left right] => "left_throw/right_bat", %w[left switch] => "left_throw/switch_hitter"
  }.freeze

  describe "A1 投打の補完（画像の「(利)」）" do
    it "CSV の投打が両方とも空のカードは 0 枚" do
      blanks = csv_rows("player_cards.csv").select { |r| r["throwing_hand"].blank? || r["batting_hand"].blank? }
      expect(blanks.map { |r| r["card_seq"] }).to eq([])
    end

    it "432 枚すべてで CSV の投打が読み直しの核と一致する" do
      diffs = csv_rows("player_cards.csv").reject do |r|
        c = core.fetch(r["card_seq"])
        [ r["throwing_hand"], r["batting_hand"] ] == [ c["throwing_hand"], c["batting_hand"] ]
      end
      expect(diffs.map { |r| r["card_seq"] }).to eq([])
    end

    it "取り込まれたカードは handedness が入る（163 右投右打・166 右投左打・421 右投両打）" do
      expect(db_card(163).handedness).to eq("right_throw/right_bat")
      expect(db_card(421).handedness).to eq("right_throw/switch_hitter")
      imported = csv_rows("player_cards.csv").select { |r| r["name"].present? }.map { |r| db_card(r["card_seq"]) }
      expect(imported.compact.map(&:handedness)).to all(be_present)
    end

    it "追加した 169 枚の値は核の「(利)」どおり（hachinai6.1 は 右投右打 79・右投左打 20・左投左打 16・左投右打 2）" do
      rows = csv_rows("player_cards.csv").select { |r| r["card_source"] == "hachinai6.1" && (163..279).cover?(r["card_seq"].to_i) }
      tally = rows.map { |r| [ r["throwing_hand"], r["batting_hand"] ] }.tally
      expect(tally).to eq({ %w[right right] => 79, %w[right left] => 20, %w[left left] => 16, %w[left right] => 2 })
    end
  end

  describe "A2 名前・番号・位置・不可視文字" do
    it "66 爾子田 里乃: 名前に U+200E が無い" do
      expect(card_row(66)["name"]).to eq("爾子田 里乃")
      expect(Player.where("name LIKE ?", "%‎%").count).to eq(0)
    end

    it "317 おくでら まさし: 投手 069・左投左打。隣の 318 のヘッダ（こりゆの）が付かない" do
      card = db_card(317)
      expect(card.player.name).to eq("おくでら まさし")
      expect(card.player.number).to eq("069")
      expect(card.card_type).to eq("pitcher")
      expect(card.handedness).to eq("left_throw/left_bat")
      expect(card_row(317)["position"]).to eq("投手")
      expect(Player.find_by(name: "こりゆの").player_cards.pluck(:card_type).uniq).to eq([ "batter" ])
    end

    it "319 植田: 投手 081・右投右打。隣の 320 のヘッダ（takky）が付かず、同じ組の 304（041）と別のカードになる" do
      # 304 も PM2026 の投手「植田」。取込の鍵は (組, 選手名, 種別) なので、既存の「(2)」の付け方で区別する
      expect(card_row(319)["name"]).to eq("植田 (2)")
      expect(card_row(319)["number"]).to eq("081")
      card = db_card(319)
      expect(card.id).not_to eq(db_card(304).id)
      expect(card.handedness).to eq("right_throw/right_bat")
      expect(card.starter_stamina).to eq(7)
      expect(Player.find_by(name: "takky").player_cards.pluck(:card_type).uniq).to eq([ "batter" ])
    end

    it "317・319 の irc_macro_name は 番号と同じ（PM2026 は macro = number）" do
      expect(card_row(317)["irc_macro_name"]).to eq("069")
      expect(card_row(319)["irc_macro_name"]).to eq("081")
      pm = csv_rows("player_cards.csv").select { |r| r["card_source"] == "PM2026" && r["irc_macro_name"].present? && r["number"].present? }
      expect(pm.select { |r| r["irc_macro_name"] != r["number"] }.map { |r| r["card_seq"] }).to eq([])
    end
  end

  describe "A3 投球表・疲労 P・種別" do
    it "324 とり: 野手カードのまま投球表 20 マス・救援 1 (R)・盗塁スタート 6 を持つ。投手として使える" do
      c = db_card(324)
      expect(c.card_type).to eq("batter")
      expect(c.is_pitcher).to be(false)
      expect(c.pitching_table).to eq(core["324"]["pitching_table"])
      expect(c.pitching_table.size).to eq(20)
      expect([ c.starter_stamina, c.relief_stamina, c.is_relief_only ]).to eq([ nil, 1, true ])
      expect([ c.steal_start, c.steal_end ]).to eq([ 6, 15 ])
      expect(c.can_pitch?).to be(true)
    end

    it "375 千亦(草津): 野手カードのまま投球表 20 マス・救援 1 (R) を持つ。投手として使える" do
      c = db_card(375)
      expect(c.card_type).to eq("batter")
      expect(c.pitching_table).to eq(core["375"]["pitching_table"])
      expect([ c.starter_stamina, c.relief_stamina, c.is_relief_only ]).to eq([ nil, 1, true ])
      expect(c.can_pitch?).to be(true)
    end

    it "394 小也香: 投手カードとして入り、投球表と先発 8 を持つ" do
      c = db_card(394)
      expect(c.card_type).to eq("pitcher")
      expect(c.is_pitcher).to be(true)
      expect(c.pitching_table).to eq(core["394"]["pitching_table"])
      expect([ c.starter_stamina, c.relief_stamina, c.is_relief_only ]).to eq([ 8, nil, false ])
      expect(c.can_pitch?).to be(true)
      # 同じ組（PM2026）に野手カードとして残らない（別の組の同名カードは別物）
      expect(PlayerCard.where(player_id: c.player_id, card_set_id: c.card_set_id).pluck(:card_type)).to eq([ "pitcher" ])
    end

    it "421 息吹: 投手カードとして入り、投球表と 先発 4 / 救援 1 を持つ" do
      c = db_card(421)
      expect(c.card_type).to eq("pitcher")
      expect(c.is_pitcher).to be(true)
      expect(c.pitching_table).to eq(core["421"]["pitching_table"])
      expect([ c.starter_stamina, c.relief_stamina, c.is_relief_only ]).to eq([ 4, 1, false ])
      expect(c.can_pitch?).to be(true)
    end

    it "4 枚とも投球表は 20 マスで、疲労 P が取込の検証に収まる" do
      [ 324, 375, 394, 421 ].each do |seq|
        c = db_card(seq)
        expect(c.pitching_table.compact.size).to eq(20)
        expect(c).to be_valid
      end
    end
  end

  describe "A4 投球表の文字混入" do
    it "240 ハルヒ: 第 4 行は 2*（走 が混ざらない）。投球表は核と一致" do
      c = db_card(240)
      expect(c.pitching_table[3]).to eq("2*")
      expect(c.pitching_table).to eq(core["240"]["pitching_table"])
      expect(c.pitching_table.grep(/走/)).to eq([])
    end
  end

  describe "A5 条件「代打」" do
    {
      43 => [ "1C5", nil ], 107 => [ "対右", nil ], 132 => [ "対左", nil ], 159 => [ "対右", nil ], 160 => [ "対左", nil ]
    }.each do |seq, (trait, role)|
      it "card_seq=#{seq} は #{trait}(代打) が 1 行だけ入る" do
        expect(traits_of(seq)).to eq([ [ trait, "代打", role ] ])
      end
    end

    it "既存の代打条件（287・362）は変わらない" do
      expect(traits_of(287)).to include([ "1C5", "代打", nil ])
      expect(traits_of(362)).to include([ "ホームラン", "代打", nil ])
    end
  end

  describe "A6 けが(するごと)" do
    [ 17, 25, 146 ].each do |seq|
      it "card_seq=#{seq}: repeating=true（days は null のまま）。128 と同じ持ち方" do
        expect(db_card(seq).injury_traits).to eq([ { "type" => "standard", "days" => nil, "exemptions" => 0, "repeating" => true } ])
      end
    end

    it "128 の既存の持ち方は変わらない" do
      expect(db_card(128).injury_traits).to eq([ { "type" => "standard", "days" => 100, "exemptions" => 0, "repeating" => true } ])
    end
  end

  describe "A7 333 のホームランの重複" do
    it "333 浅草大使: traits CSV のホームランが 1 行（取込は同じ行を 1 行に潰すので CSV 側で見る）" do
      rows = csv_rows("player_card_traits.csv").select { |r| r["card_seq"] == "333" }
      expect(rows.map { |r| [ r["trait_definition_name"], r["condition_name"], r["role"], r["sort_order"] ] }).to eq([ [ "ホームラン", nil, nil, "0" ] ])
      expect(traits_of(333)).to eq([ [ "ホームラン", nil, nil ] ])
    end
  end

  describe "触らないもの" do
    # 旧: 「331・332・339 は名前が空のまま（取り込まれない）」。Operator が全カード取り込みへ方針変更したため（cmd_1891、2026-11-13）、
    # 名前を入れて取り込む形に変えた。名前・番号・位置の中身は import_card_official_use_spec.rb が確かめる。
    it "331・332・339 は名前が入って取り込まれる（全カード取り込み方針。旧期待値は空のまま）" do
      [ 331, 332, 339 ].each do |seq|
        expect(card_row(seq)["name"]).to be_present
        expect(db_card(seq)).to be_present
      end
    end

    it "二刀流の打撃表 5 列目の K 埋め（20・240・388・389・402・403・413・419）は現状のまま" do
      [ 20, 240, 388, 389, 402, 403, 413, 419 ].each do |seq|
        bt = JSON.parse(card_row(seq)["batting_table"])
        expect(bt.map { |r| r[4] }.count("K")).to be >= 11
      end
    end
  end
end
