require "rails_helper"
require "rake"
require "tmpdir"
require "csv"

RSpec.describe "import:card_data" do
  before(:all) do
    Rails.application.load_tasks
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
      throwing_hand batting_hand is_pitcher speed bunt steal_start steal_end
      injury_rate is_relief_only starter_stamina relief_stamina batting_style_id
      pitching_style_id is_closer unique_traits injury_traits biorhythm_period
      biorhythm_date_ranges batting_table pitching_table card_label irc_macro_name irc_display_name
    ]
  end

  # 霊夢カード(2025THBIG, 投手)
  let(:reimu_row) do
    [
      "1", "", "", "06", "投手", "博麗 霊夢", "2025THBIG", "ok",
      "right", "right", "true", "1", "7", "1", "1",
      "5", "false", "6", "1", "", "", "false",
      "", "", "", "", "[]", "[]", "06", "reimu", "reimu_irc"
    ]
  end

  # マリサカード(2025THBIG, 野手)
  let(:marisa_row) do
    [
      "2", "", "", "09", "外野手", "霧雨 魔理沙", "2025THBIG", "ok",
      "right", "right", "false", "3", "5", "10", "10",
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
        "right", "right", "true", "3", "5", "10", "10",
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

  describe "CARD_DATA_DIR環境変数" do
    it "CARD_DATA_DIR引数でCSVディレクトリを指定できる" do
      Rake::Task["import:card_data"].invoke
      expect(CardSet.count).to eq(1)
    end
  end
end
