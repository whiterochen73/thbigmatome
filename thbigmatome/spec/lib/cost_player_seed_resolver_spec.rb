require "rails_helper"

RSpec.describe CostPlayerSeedResolver do
  before do
    described_class.clear_cache!
  end

  after do
    described_class.clear_cache!
  end

  describe ".resolve" do
    it "resolves a variant seed row to the base player and variant player card" do
      base_player = create(:player, name: "初瀬 麻里安")
      create(:player, name: "初瀬 麻里安 (湘南)")
      card_set = create(:card_set, name: "PM2026", set_type: "pm2026")
      player_card = create(:player_card, player: base_player, card_set: card_set, variant: "湘南")

      resolution = described_class.resolve("初瀬　麻里安（湘南）")

      expect(resolution.player).to eq(base_player)
      expect(resolution.player_card).to eq(player_card)
    end

    it "keeps exact variant players when cards use suffix names without variant metadata" do
      create(:player, name: "川崎 稜")
      exact_player = create(:player, name: "川崎 稜 (1年)")
      create(:player_card, player: exact_player, variant: nil)

      resolution = described_class.resolve("川崎　稜（１年）")

      expect(resolution.player).to eq(exact_player)
      expect(resolution.player_card).to be_nil
    end
  end

  describe "card_seq 列（PM のカード 1 枚を指す行）" do
    # card_seq 479 = db/import/player_cards.csv の PM2027「魅魔（エイプリル）」投手
    let(:player) { create(:player, name: "魅魔") }
    let!(:pm2026_set) { create(:card_set, name: "PM2026", set_type: "pm2026") }
    let!(:pm2027_set) { create(:card_set, name: "PM2027", set_type: "pm2027") }
    let!(:pm2026_card) { create(:player_card, player: player, card_set: pm2026_set, card_type: "pitcher", variant: "エイプリル") }
    let!(:pm2027_card) { create(:player_card, player: player, card_set: pm2027_set, card_type: "pitcher", variant: "エイプリル") }

    it "同じ variant の別セットのカードがあっても、card_seq の出典のカードに当たる（名前では PM2026 のカードに当たる）" do
      by_seq = described_class.resolve("読む人のための表記", card_seq: "479")
      by_name = described_class.resolve("魅魔（エイプリル）")

      expect(by_seq.player).to eq(player)
      expect(by_seq.player_card).to eq(pm2027_card)
      expect(by_name.player_card).to eq(pm2026_card)
    end

    it "card_source に対応するカードセットの名前は config/card_set_definitions.yml（CardSet::IMPORT_DEFINITIONS）から引く" do
      # 定義側の name だけを替えると、card_seq の当て先もその名前のセットへ動く（resolver が別の対応表を持たない）
      renamed = create(:card_set, name: "PM2027改名", set_type: "pm2027_renamed")
      renamed_card = create(:player_card, player: player, card_set: renamed, card_type: "pitcher", variant: "エイプリル")
      defs = CardSet::IMPORT_DEFINITIONS.merge("PM2027" => CardSet::IMPORT_DEFINITIONS.fetch("PM2027").merge(name: "PM2027改名")).freeze
      stub_const("CardSet::IMPORT_DEFINITIONS", defs)

      expect(described_class.resolve("読む人のための表記", card_seq: "479").player_card).to eq(renamed_card)
    end

    it "取り込んでいないカード・CSV に無い card_seq は選手なし（読み飛ばし）になる" do
      pm2027_card.destroy!
      expect(described_class.resolve("魅魔", card_seq: "479").player).to be_nil
      expect(described_class.resolve("魅魔", card_seq: "999999").player).to be_nil
    end

    it "assign! は card_seq の行を player_card_id つきで作り、player_name 列は当て先に使わない" do
      cost = create(:cost)
      row = { "player_name" => "存在しない名前", "card_seq" => "479", "normal_cost" => "15", "cost_exempt" => "false" }

      cost_player = described_class.assign!(cost, row)

      expect(cost_player.player_card).to eq(pm2027_card)
      expect(cost_player.normal_cost).to eq(15)
      expect(CostPlayer.where(cost: cost, player: player, player_card_id: nil)).not_to exist
    end

    it "card_seq が空の行は従来どおり名前で当たる" do
      cost = create(:cost)
      row = { "player_name" => "魅魔（エイプリル）", "card_seq" => nil, "normal_cost" => "15", "cost_exempt" => "false" }

      expect(described_class.assign!(cost, row).player_card).to eq(pm2026_card)
    end
  end

  describe ".assign!" do
    it "creates cost players with player_card_id for variant rows" do
      cost = create(:cost)
      base_player = create(:player, name: "初瀬 麻里安")
      player_card = create(:player_card, player: base_player, variant: "町田")
      row = {
        "player_name" => "初瀬　麻里安（町田）",
        "normal_cost" => "8",
        "relief_only_cost" => nil,
        "pitcher_only_cost" => nil,
        "fielder_only_cost" => nil,
        "two_way_cost" => nil,
        "cost_exempt" => "false"
      }

      cost_player = described_class.assign!(cost, row)

      expect(cost_player.player).to eq(base_player)
      expect(cost_player.player_card).to eq(player_card)
      expect(cost_player.normal_cost).to eq(8)
    end
  end

  describe "card_seq 行の当て先（variant の無い行）" do
    # card_seq 405 = db/import/player_cards.csv の PM2026「小鳥遊 柚」（variant 空）。本番では PM2026 に variant「UR」の既存カードしか無く
    # （取り込みは variant の無い行で variant を鍵にせず、そのカードを行のカードとして使う）、行のカードは作られていない。
    # UR のカードにコストを付けると取り違えになるので、読み飛ばしにする
    it "variant つきのカードしか無い時は当てない（UR のカードに寄せない）" do
      player = create(:player, name: "小鳥遊 柚")
      set = create(:card_set, name: "PM2026", set_type: "pm2026")
      create(:player_card, player: player, card_set: set, card_type: "batter", variant: "UR")

      resolution = described_class.resolve("小鳥遊 柚 PM2026", card_seq: "405")

      expect([ resolution.player, resolution.player_card ]).to eq([ nil, nil ])
    end

    it "variant の無いカードがあればそれに当てる" do
      player = create(:player, name: "小鳥遊 柚")
      set = create(:card_set, name: "PM2026", set_type: "pm2026")
      plain = create(:player_card, player: player, card_set: set, card_type: "batter", variant: nil)
      create(:player_card, player: player, card_set: set, card_type: "batter", variant: "UR")

      expect(described_class.resolve("小鳥遊 柚 PM2026", card_seq: "405").player_card).to eq(plain)
    end
  end

  describe "db/import/cost_players_seed.csv の名前の書き方（cmd_1898 subtask_1898b）" do
    let(:rows) { CSV.read(Rails.root.join("db/import/cost_players_seed.csv"), headers: true) }

    it "「名前＋数字」（badferd2・智夜2 など）は DB の Player の書式「名前 (数字)」で書かれている" do
      bare_digit = rows.map { |r| r["player_name"] }.select { |n| n.to_s.match?(/[^\s\d(][2-9]\z/) && n.to_s.match?(/\A[^\s]+\z/) }

      expect(bare_digit).to be_empty
    end

    it "全角空白の「駒草　山如」「二ツ岩」は DB の Player 名（駒草 山如(太夫)・二ッ岩 マミゾウ）で書かれている" do
      names = rows.map { |r| r["player_name"] }

      expect(names).to include("駒草 山如(太夫)", "二ッ岩 マミゾウ")
      expect(names).not_to include("駒草　山如", "二ツ岩　マミゾウ")
    end

    it "同じ cost_name の中で、同じ名前の行が 2 つある時は card_seq で区別されている（黙って上書きしない）" do
      keyed = rows.group_by { |r| [ r["cost_name"], r["player_name"], r["card_seq"].to_s ] }

      expect(keyed.select { |_k, v| v.size > 1 }).to be_empty
    end
  end
end
