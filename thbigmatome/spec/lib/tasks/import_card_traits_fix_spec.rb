require "rails_helper"
require "rake"
require "csv"

# 実データ（db/import/*.csv）を import:card_data に通し、固有特徴 57 枚の特徴の取り込み結果を確かめる。
#
# Test Basis:
#   - context/thbig-unique-traits-interpretation.md §4a（unique_traits の文面と画像の食い違い）
#   - 同 §4b（構造化列と画像の食い違い）/ §7（発見事項）
#   - context/thbig-bench-rule-adjudications.md AMB-35 Q1（スラッシュ特徴は 左=無走者 / 右=有走者）
# 「画像」は ~/projects/thbigmatome/tmp/card_images/ の原本。card_seq は同 §3 の表の番号。
# 既存の表現で表せず直せなかったものは、このファイルでは「現状のまま」を固定していない。
RSpec.describe "import:card_data（固有特徴の取り込み・実データ）" do
  let(:data_dir) { Rails.root.join("db/import").to_s }
  let(:set_names) { { "2025THBIG" => "2025THBIG", "hachinai6.1" => "ハチナイ6.1", "PM2026" => "PM2026", "tamayomi2" => "球詠2" } }

  # 実データの import は 1 回で数秒かかるため、ブロック全体で 1 回だけ流す（トランザクション外）。
  # 後始末は after(:all) で全表を空にする（suite は before(:suite) で truncation 済みの前提）。
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("import:card_data")
    ENV["CARD_DATA_DIR"] = Rails.root.join("db/import").to_s
    Rake::Task["import:card_data"].reenable
    load Rails.root.join("db/seeds/master_traits.rb") # 本番と同じ特徴・条件マスタ
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

  def csv_rows(file)
    CSV.read(File.join(data_dir, file), headers: true)
  end

  def card_row(seq)
    csv_rows("player_cards.csv").find { |r| r["card_seq"] == seq.to_s }
  end

  # import 済みの DB から card_seq のカードを引く（名前の空白差は import と同じ正規化）
  def db_card(seq)
    row = card_row(seq)
    player = Player.find_by("REPLACE(REPLACE(name, ' ', ''), '　', '') = ?", row["name"].gsub(/[\s　]+/, ""))
    PlayerCard.find_by(player_id: player&.id,
                       card_set_id: CardSet.find_by(name: set_names[row["card_source"]])&.id,
                       card_type: row["card_type"])
  end

  # [特徴名, 条件名, role] を sort_order 順に返す
  def traits_of(seq)
    db_card(seq).player_card_traits.includes(:trait_definition, :condition).order(:sort_order, :id)
                .map { |t| [ t.trait_definition.name, t.condition&.name, t.role ] }
  end

  describe "投手・野手で特徴が分かれるカードの role（§4b 二刀流 role 空欄 / 標準の特徴語が構造化に無い）" do
    {
      29  => [ %w[ホームラン pitcher], %w[DB batter] ],
      288 => [ %w[対右 pitcher], %w[チャンス batter] ],
      306 => [ %w[対右 pitcher], %w[1C5 batter] ],
      379 => [ %w[DB pitcher], %w[チャンス batter] ],
      419 => [ %w[対右 pitcher], %w[対左 batter] ],
      324 => [ %w[WP pitcher], %w[内野安打 batter] ],
      421 => [ %w[対右 pitcher], %w[DB batter] ]
    }.each do |seq, expected|
      it "card_seq=#{seq} は投手側・野手側の特徴が role つきで入り、role が空にならない" do
        rows = traits_of(seq)
        expect(rows.map { |n, _, r| [ n, r ] }).to eq(expected)
        expect(rows.map(&:last)).to all(be_present)
        expect(rows.map { |_, c, _| c }).to all(be_nil)
      end
    end

    it "375 千亦: 投手側のホームランが role=pitcher で入る（野手側の暴言退場・対左は保留）" do
      expect(traits_of(375)).to eq([ [ "ホームラン", nil, "pitcher" ] ])
    end
  end

  describe "条件つきの特徴は条件ごとに別行で入り、条件なしの行は最後（§4b 条件が落ちて先頭が常に選ばれる）" do
    it "60 サグメ: 同点=DB / リード=ホームラン / ビハインド=三振" do
      expect(traits_of(60)).to eq([ [ "DB", "同点", nil ], [ "ホームラン", "リード", nil ], [ "三振", "ビハインド", nil ] ])
    end

    it "70 ドレミー: 満塁=ホームラン、それ以外=対右" do
      expect(traits_of(70)).to eq([ [ "ホームラン", "満塁", nil ], [ "対右", nil, nil ] ])
    end

    it "362 諏訪子: 代打=ホームラン、それ以外=三振" do
      expect(traits_of(362)).to eq([ [ "ホームラン", "代打", nil ], [ "三振", nil, nil ] ])
    end

    it "359 早苗: 満塁=ホームラン（それ以外の「代打」特徴は既存の特徴名に無いので保留）" do
      expect(traits_of(359)).to eq([ [ "ホームラン", "満塁", nil ] ])
    end
  end

  describe "AMB-35 Q1: スラッシュ特徴は 左=走者なし / 右=走者あり" do
    it "178 千景: DB=無走者 / WP=有走者" do
      expect(traits_of(178)).to eq([ [ "DB", "無走者", nil ], [ "WP", "有走者", nil ] ])
    end

    it "394 小也香: (無走者)対右 (有走者)WP" do
      expect(traits_of(394)).to eq([ [ "対右", "無走者", nil ], [ "WP", "有走者", nil ] ])
    end

    it "388 麻里安(湘南): 野手=対左、投手=対右(無走者)/WP(有走者)" do
      expect(traits_of(388)).to eq([ [ "対左", nil, "batter" ], [ "対右", "無走者", "pitcher" ], [ "WP", "有走者", "pitcher" ] ])
    end

    it "389 麻里安(町田): 野手=対左、投手=DB(無走者)/WP(有走者)" do
      expect(traits_of(389)).to eq([ [ "対左", nil, "batter" ], [ "DB", "無走者", "pitcher" ], [ "WP", "有走者", "pitcher" ] ])
    end
  end

  describe "標準の特徴語が構造化に無い（§4b）" do
    it "103 正邪: 「対左」が入る" do
      expect(traits_of(103)).to eq([ [ "対左", nil, nil ] ])
    end
  end

  describe "専属捕手つきのカード（既存の並びに揃える: 通常の特徴が先、専属側が後ろ。271 と同じ並び）" do
    it "415 詠深: ホームランが先頭、三振振り逃げ(無走者)・WP(有走者)が後ろ、専属捕手に 山崎 珠姫" do
      expect(traits_of(415)).to eq([ [ "ホームラン", nil, nil ], [ "三振振り逃げ", "無走者", nil ], [ "WP", "有走者", nil ] ])
      names = db_card(415).player_card_exclusive_catchers.map { |c| Player.find(c.catcher_player_id).name }
      expect(names).to eq([ "山崎 珠姫" ])
    end
  end

  describe "injury_traits（§4b injury_traits の欠落・値の誤り）" do
    def injury(seq) = db_card(seq).injury_traits

    it "128 ニナ: けが100日は「するごと」なので repeating=true" do
      expect(injury(128)).to eq([ { "type" => "standard", "days" => 100, "exemptions" => 0, "repeating" => true } ])
    end

    it "247 ゆり: 右手骨折＊（免除 1 回）のあと けが53日" do
      expect(injury(247)).to eq([ { "type" => "standard", "days" => 53, "exemptions" => 1, "repeating" => false } ])
    end

    it "151 幽々子: 背筋痛20日" do
      expect(injury(151)).to eq([ { "type" => "standard", "days" => 20, "exemptions" => 0, "repeating" => false } ])
    end

    it "354 鈴仙: 右肩故障＊＊＊ の免除 3 回（今季絶望は既存の表現で表せず保留）" do
      expect(injury(354).sum { |e| e["exemptions"].to_i }).to eq(3)
    end

    # 365 は irc_macro_name=00 が別カード(292)と衝突して import がカードを作らない（既知の別問題）ため CSV で確かめる
    it "365 幽々子(楼閣): 背筋痛20日・腰痛10日（CSV）" do
      expect(JSON.parse(card_row(365)["injury_traits"])).to eq([
        { "type" => "standard", "days" => 20, "exemptions" => 0, "repeating" => false },
        { "type" => "standard", "days" => 10, "exemptions" => 0, "repeating" => false }
      ])
    end

    it "「けが(するごと)」の 17 / 25 / 146 は days=null のまま（通常のけが判定）で、repeating=true（cmd_1888: 128 と同じ持ち方）" do
      [ 17, 25, 146 ].each do |seq|
        expect(injury(seq)).to eq([ { "type" => "standard", "days" => nil, "exemptions" => 0, "repeating" => true } ])
      end
    end
  end

  describe "333 浅草大使（名前が空欄で import されなかったカード）" do
    it "名前が入り、投手のカードとして import される" do
      card = db_card(333)
      expect(card).to be_present
      expect(card.player.name).to eq("浅草大使")
      expect(card.card_type).to eq("pitcher")
      expect(card.is_relief_only).to be(true)
      expect(card.injury_traits).to eq([ { "type" => "standard", "days" => 30, "exemptions" => 1, "repeating" => false } ])
      expect(card.player_card_defenses.pluck(:position, :range_value, :error_rank)).to eq([ [ "P", 4, "A" ] ])
    end
  end

  describe "unique_traits の文面（§4a）" do
    def text(seq) = db_card(seq).unique_traits.to_s

    it "投球列の数字が混入していない（324 / 375 / 394 / 421）" do
      [ 324, 375, 394, 421 ].each do |seq|
        stray = text(seq).split("\n").select { |l| l.match?(/\A\s*\d\s*\z/) }
        expect(stray).to be_empty, "card_seq=#{seq}: #{text(seq).inspect}"
      end
    end

    it "359: (それ以外) のあとに 代打 が残る" do
      expect(text(359).split("\n").last(2)).to eq(%w[(それ以外) 代打])
    end

    it "393: 専属捕手の条件（レイセン・DB）と ~9/24 左手突き指 が残る" do
      expect(text(393)).to include("【専属捕手】").and include("レイセン").and include("DB").and include("左手突き指")
    end

    it "379: 登板前後出場不可 が残る" do
      expect(text(379)).to include("登板前後").and include("出場不可")
    end

    it "354: 精神疲労の注記が残る" do
      expect(text(354)).to include("精神疲労").and include("失点すると")
    end

    it "362: 早苗登板時・降板後の守備の条件が文面に残る（defenses には条件の列が無い）" do
      expect(text(362)).to include("早苗登板時").and include("早苗降板後")
    end
  end

  describe "回帰ガード: CSV の名前が黙って落ちない（不正入力）" do
    it "player_card_traits.csv の特徴名・条件名はすべてマスタにあり、role は batter / pitcher / 空のみ" do
      trait_names = TraitDefinition.pluck(:name)
      cond_names = TraitCondition.pluck(:name)
      csv_rows("player_card_traits.csv").each do |r|
        expect(trait_names).to include(r["trait_definition_name"]), "card_seq=#{r['card_seq']}: 未登録の特徴名 #{r['trait_definition_name']}"
        if r["condition_name"].present?
          expect(cond_names).to include(r["condition_name"]), "card_seq=#{r['card_seq']}: 未登録の条件名 #{r['condition_name']}"
        end
        expect([ nil, "", "batter", "pitcher" ]).to include(r["role"])
      end
    end

    it "同一カード・同一 role で、条件つきの行が条件なしの行より前に並ぶ（専属捕手の 2 行は除く: 専属側が後ろの並び）" do
      exclusive = csv_rows("player_card_exclusive_catchers.csv").map { |r| r["card_seq"] }.uniq
      csv_rows("player_card_traits.csv").group_by { |r| [ r["card_seq"], r["role"].to_s ] }.each do |(seq, role), rs|
        next if exclusive.include?(seq)
        conds = rs.sort_by { |r| r["sort_order"].to_i }.map { |r| r["condition_name"].present? }
        next unless conds.include?(true) && conds.include?(false)
        expect(conds).to eq(conds.sort_by { |c| c ? 0 : 1 }), "card_seq=#{seq} role=#{role.inspect}: 条件つきの行が条件なしの行の後ろにある"
      end
    end

    it "同一カード・同一 role で、別の特徴が同じ sort_order にならない" do
      groups = csv_rows("player_card_traits.csv").group_by { |r| [ r["card_seq"], r["role"].to_s, r["sort_order"] ] }
      conflicting = groups.select { |_, v| v.map { |r| [ r["trait_definition_name"], r["condition_name"] ] }.uniq.size > 1 }
      expect(conflicting.keys).to be_empty
    end
  end
end
