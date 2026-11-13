require "rails_helper"
require "rake"
require "tmpdir"
require "csv"

RSpec.describe "import:card_data" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("import:card_data")
  end

  let(:tmp_dir) { Dir.mktmpdir }

  before do
    ENV["CARD_DATA_DIR"] = tmp_dir
    Rake::Task["import:card_data"].reenable
  end

  after do
    ENV.delete("CARD_DATA_DIR")
    FileUtils.rm_rf(tmp_dir)
  end

  # ヘルパー: CSVファイルを tmp_dir に書き出す
  def write_csv(filename, rows)
    path = File.join(tmp_dir, filename)
    CSV.open(path, "w") do |csv|
      rows.each { |row| csv << row }
    end
  end

  let(:player_cards_headers) do
    %w[
      card_seq player_id card_set_id number position name card_source parse_status
      throwing_hand batting_hand is_pitcher card_type speed bunt steal_start steal_end
      injury_rate is_relief_only starter_stamina relief_stamina batting_style_id
      pitching_style_id is_closer unique_traits injury_traits biorhythm_period
      biorhythm_date_ranges batting_table pitching_table card_label irc_macro_name irc_display_name
    ]
  end

  # 霊夢カード(2025THBIG, 投手)
  let(:reimu_row) do
    [
      "1", "", "", "06", "投手", "博麗 霊夢", "2025THBIG", "ok",
      "right", "right", "true", "pitcher", "1", "7", "1", "1",
      "5", "false", "6", "1", "", "", "false",
      "", "", "", "", "[]", "[]", "06", "reimu", "reimu_irc"
    ]
  end

  # マリサカード(2025THBIG, 野手)
  let(:marisa_row) do
    [
      "2", "", "", "09", "外野手", "霧雨 魔理沙", "2025THBIG", "ok",
      "right", "right", "false", "batter", "3", "5", "10", "10",
      "3", "false", "", "", "", "", "false",
      "", "", "", "", "[]", "[]", "09", "marisa", "marisa_irc"
    ]
  end

  let(:defense_headers) { %w[card_seq position range_value error_rank throwing] }
  let(:trait_headers)   { %w[card_seq trait_definition_name condition_name role sort_order] }
  let(:ability_headers) { %w[card_seq ability_definition_name role sort_order] }
  let(:catcher_headers) { %w[card_seq catcher_name_raw] }

  before do
    write_csv("player_cards.csv", [ player_cards_headers, reimu_row, marisa_row ])
    write_csv("player_card_defenses.csv", [
      defense_headers,
      [ "1", "P", "5", "B", "" ],
      [ "2", "OF", "3", "A", "S" ]
    ])
    write_csv("player_card_traits.csv", [
      trait_headers,
      [ "1", "対右", "", "", "0" ],
      [ "2", "対左", "", "", "0" ]
    ])
    write_csv("player_card_abilities.csv", [ ability_headers ])
    write_csv("player_card_exclusive_catchers.csv", [ catcher_headers ])

    # TraitDefinition seed (traits referenced in CSV)
    TraitDefinition.find_or_create_by!(name: "対右") { |t| t.description = "test" }
    TraitDefinition.find_or_create_by!(name: "対左") { |t| t.description = "test" }
  end

  describe "基本インポート" do
    it "CSVからCardSet/Player/PlayerCardが作成される" do
      expect {
        Rake::Task["import:card_data"].invoke
      }.to change(CardSet, :count).by(1)
        .and change(Player, :count).by(2)
        .and change(PlayerCard, :count).by(2)
    end

    it "CardSetのname/year/set_typeが正しく設定される" do
      Rake::Task["import:card_data"].invoke
      cs = CardSet.find_by!(name: "2025THBIG")
      expect(cs.year).to eq(2025)
      expect(cs.set_type).to eq("annual")
    end

    it "PlayerCardのスタットが正しく設定される" do
      Rake::Task["import:card_data"].invoke
      pc = PlayerCard.joins(:player).find_by!(players: { name: "博麗 霊夢" })
      expect(pc.speed).to eq(1)
      expect(pc.bunt).to eq(7)
      expect(pc.is_pitcher).to be(true)
      expect(pc.irc_macro_name).to eq("reimu")
    end

    it "疲労P「1C」のクローザー（八雲 紫）が is_closer=true で取り込まれ、疲労値は 1 のまま" do
      yukari_row = [
        "142", "", "", "18", "投手", "八雲 紫", "2025THBIG", "ok",
        "right", "right", "true", "pitcher", "1", "1", "1", "1",
        "4", "false", "", "1", "", "", "true",
        "", "", "", "", "[]", "[]", "18", "yukari", "yukari_irc"
      ]
      write_csv("player_cards.csv", [ player_cards_headers, reimu_row, marisa_row, yukari_row ])
      Rake::Task["import:card_data"].invoke
      yukari = PlayerCard.joins(:player).find_by!(players: { name: "八雲 紫" })
      expect(yukari.is_closer).to be(true)
      expect(yukari.is_relief_only).to be(false)
      expect(yukari.relief_stamina).to eq(1)
      reimu = PlayerCard.joins(:player).find_by!(players: { name: "博麗 霊夢" })
      expect(reimu.is_closer).to be(false)
    end

    it "同梱の player_cards.csv では C 付き 4 枚（紫 142・382、隠岐奈 65・336）だけが is_closer=true" do
      rows = CSV.read(Rails.root.join("db/import/player_cards.csv"), headers: true)
      closers = rows.select { |r| r["is_closer"] == "true" }
      expect(closers.map { |r| r["card_seq"].to_i }.sort).to eq([ 65, 142, 336, 382 ])
      expect(closers.map { |r| r["name"] }.uniq).to match_array([ "摩多羅 隠岐奈", "八雲 紫" ])
      expect(closers.map { |r| r["relief_stamina"] }.uniq).to eq([ "1" ])
    end

    it "PlayerCardDefenseが紐付け先のPlayerCardに作成される" do
      Rake::Task["import:card_data"].invoke
      pc = PlayerCard.joins(:player).find_by!(players: { name: "博麗 霊夢" })
      expect(pc.player_card_defenses.count).to eq(1)
      defense = pc.player_card_defenses.first
      expect(defense.position).to eq("P")
      expect(defense.range_value).to eq(5)
      expect(defense.error_rank).to eq("B")
    end

    it "PlayerCardTraitがTraitDefinitionと正しく紐付く" do
      Rake::Task["import:card_data"].invoke
      pc = PlayerCard.joins(:player).find_by!(players: { name: "博麗 霊夢" })
      trait_names = pc.player_card_traits.joins(:trait_definition).pluck("trait_definitions.name")
      expect(trait_names).to include("対右")
    end
  end

  describe "2枚持ち（同一選手に投手・野手両方のカード）" do
    let(:two_way_pitcher_row) do
      [
        "3", "", "", "10", "投手", "有原 翼", "hachinai6.1", "ok",
        "right", "right", "true", "pitcher", "3", "8", "1", "1",
        "5", "false", "6", "1", "", "", "false",
        "", "", "", "", "[]", "[]", "P1", "arahara_p", ""
      ]
    end
    let(:two_way_batter_row) do
      [
        "4", "", "", "10", "内野手", "有原 翼", "hachinai6.1", "ok",
        "right", "right", "false", "batter", "4", "3", "9", "16",
        "6", "false", "", "", "", "", "false",
        "", "", "", "", "[]", "[]", "F1", "arahara_f", ""
      ]
    end

    before do
      CardSet.find_or_create_by!(name: "ハチナイ6.1") do |cs|
        cs.year = 2026
        cs.set_type = "hachinai61"
      end
      write_csv("player_cards.csv", [
        player_cards_headers,
        reimu_row,
        marisa_row,
        two_way_pitcher_row,
        two_way_batter_row
      ])
    end

    it "同一選手の投手・野手カードが両方作成される" do
      expect {
        Rake::Task["import:card_data"].invoke
      }.to change(PlayerCard, :count).by(4)
    end

    it "有原 翼の投手・野手カードがcard_typeで区別される" do
      Rake::Task["import:card_data"].invoke
      player = Player.find_by!(name: "有原 翼")
      pitcher_card = PlayerCard.find_by!(player: player, card_type: "pitcher")
      batter_card  = PlayerCard.find_by!(player: player, card_type: "batter")
      expect(pitcher_card).to be_present
      expect(batter_card).to be_present
      expect(pitcher_card.is_pitcher).to be(true)
      expect(batter_card.is_pitcher).to be(false)
    end
  end

  describe "冪等性テスト" do
    it "2回実行しても件数が変わらない" do
      Rake::Task["import:card_data"].invoke
      counts_first = {
        card_set:     CardSet.count,
        player:       Player.count,
        player_card:  PlayerCard.count,
        defense:      PlayerCardDefense.count,
        trait:        PlayerCardTrait.count
      }

      Rake::Task["import:card_data"].reenable
      Rake::Task["import:card_data"].invoke
      counts_second = {
        card_set:     CardSet.count,
        player:       Player.count,
        player_card:  PlayerCard.count,
        defense:      PlayerCardDefense.count,
        trait:        PlayerCardTrait.count
      }

      expect(counts_second).to eq(counts_first)
    end
  end

  describe "スキップ処理" do
    before do
      # injury_rateが空の行を追加
      skip_row = [
        "99", "", "", "99", "投手", "テスト選手", "2025THBIG", "ok",
        "right", "right", "true", "pitcher", "3", "5", "10", "10",
        "", "false", "6", "", "", "", "false",
        "", "", "", "", "[]", "[]", "", "", ""
      ]
      write_csv("player_cards.csv", [ player_cards_headers, reimu_row, marisa_row, skip_row ])
    end

    it "必須スタットが欠損している行はスキップされ件数に影響しない" do
      Rake::Task["import:card_data"].invoke
      expect(Player.find_by(name: "テスト選手")).to be_nil
    end
  end

  describe "irc_macro_name の重複防止（既存 DB の行との照合）" do
    def row_with(seq, name, macro)
      reimu_row.dup.tap { |r| r[0] = seq; r[3] = macro; r[5] = name; r[30] = macro }
    end

    it "CSV の中で macro が一意なら、DB に既にある同じ macro の別名カードは本当の重複として取り込まない" do
      write_csv("player_cards.csv", [ player_cards_headers, row_with("1", "博麗 霊夢", "reimu") ])
      Rake::Task["import:card_data"].invoke
      expect(PlayerCard.count).to eq(1)

      write_csv("player_cards.csv", [ player_cards_headers, row_with("2", "霊夢(表記ゆれ)", "reimu") ])
      Rake::Task["import:card_data"].reenable
      Rake::Task["import:card_data"].invoke
      expect(PlayerCard.count).to eq(1)
      expect(PlayerCard.first.player.name).to eq("博麗 霊夢")
    end

    it "CSV の中で macro が複数枚に共通する組（PM2026 の背番号共有）は別カードとして両方取り込む" do
      write_csv("player_cards.csv", [ player_cards_headers, row_with("1", "博麗 霊夢", "9"), row_with("2", "霧雨 魔理沙", "9") ])
      Rake::Task["import:card_data"].invoke
      expect(PlayerCard.count).to eq(2)
    end
  end

  describe "CARD_DATA_DIR環境変数" do
    it "CARD_DATA_DIR引数でCSVディレクトリを指定できる" do
      Rake::Task["import:card_data"].invoke
      expect(CardSet.count).to eq(1)
    end
  end
end
