require "rails_helper"

# Test Basis: cmd_1898 subtask_1898b §2（画像の取り込みが、添え字（版・チーム名）つきの行を取り込みと同じ引き方で当てる）。
# 引き方は db/seeds/import_cards.rb の Step 1 と同じ: 出典のセット・持ち主（variant と base_player_name があれば基の選手）・種別・variant
RSpec.describe PlayerCardLocator do
  let!(:pm2027) { create(:card_set, name: "PM2027", set_type: "pm2027") }
  let!(:pm2026) { create(:card_set, name: "PM2026", set_type: "pm2026", is_current: false) }

  before { described_class.clear_cache! }
  after { described_class.clear_cache! }

  def row(overrides = {})
    { "card_seq" => "1", "name" => "x", "card_source" => "PM2027", "card_type" => "batter", "variant" => nil, "base_player_name" => nil, "is_pitcher" => "false" }.merge(overrides)
  end

  describe ".locate" do
    it "添え字つきの名前の行は、カードが付いている基の Player に variant で当たる（名前の Player は無くてよい）" do
      base = create(:player, name: "八雲 紫")
      card = create(:player_card, player: base, card_set: pm2027, variant: "飯能")
      create(:player_card, player: base, card_set: pm2027, variant: "筑紫野")

      result = described_class.locate(row("name" => "八雲 紫 (飯能)", "variant" => "飯能", "base_player_name" => "八雲 紫"))

      expect(result.card).to eq(card)
    end

    it "variant を見て当てる（同じ Player・同じ種別の別 variant のカードに取り違えない）" do
      base = create(:player, name: "潮見 凪沙")
      create(:player_card, player: base, card_set: pm2027, card_type: "pitcher", variant: "伏見")
      wanted = create(:player_card, player: base, card_set: pm2027, card_type: "pitcher", variant: "UR")

      result = described_class.locate(row("name" => "潮見 凪沙", "card_type" => "pitcher", "variant" => "UR", "base_player_name" => "潮見 凪沙"))

      expect(result.card).to eq(wanted)
    end

    it "カードセット・種別も見る（PM2026 のカードや別種別に当てない）" do
      player = create(:player, name: "魂魄 妖夢")
      create(:player_card, player: player, card_set: pm2026, variant: "幽冥")
      create(:player_card, player: player, card_set: pm2027, card_type: "pitcher", variant: "幽冥")

      result = described_class.locate(row("name" => "魂魄 妖夢", "variant" => "幽冥", "base_player_name" => "魂魄 妖夢"))

      expect(result.card).to be_nil
      expect(result.reason).to eq("card_missing")
    end

    it "基の Player が無ければ行の名前の Player（variant つきのカード）を引く" do
      player = create(:player, name: "冴月 麟 (野手)")
      card = create(:player_card, player: player, card_set: pm2027, variant: "野手")

      result = described_class.locate(row("name" => "冴月 麟 (野手)", "variant" => "野手"))

      expect(result.card).to eq(card)
    end

    it "名前の空白・全角空白・全角半角の違いは寄せて引く" do
      player = create(:player, name: "駒草 山如")
      card = create(:player_card, player: player, card_set: pm2027)

      expect(described_class.locate(row("name" => "駒草　山如")).card).to eq(card)
    end

    it "variant の無い行は variant の無いカードを先に取る" do
      player = create(:player, name: "小鳥遊 柚")
      plain = create(:player_card, player: player, card_set: pm2027, variant: nil)
      create(:player_card, player: player, card_set: pm2027, variant: "UR")

      expect(described_class.locate(row("name" => "小鳥遊 柚")).card).to eq(plain)
    end

    it "variant の無い行は variant つきのカードに寄せない（取り込みが行のカードを作らなかった時、UR のカードに画像・コストを付ける取り違えを避ける）" do
      player = create(:player, name: "小鳥遊 柚")
      create(:player_card, player: player, card_set: pm2026, variant: "UR")

      result = described_class.locate(row("name" => "小鳥遊 柚", "card_source" => "PM2026"))

      expect(result.card).to be_nil
      expect(result.reason).to eq("card_missing")
    end

    it "選手もカードセットも無ければ理由つきで nil" do
      expect(described_class.locate(row("name" => "いない")).reason).to eq("player_missing")
      create(:player, name: "いる")
      described_class.clear_cache!
      expect(described_class.locate(row("name" => "いる", "card_source" => "2025THBIG")).reason).to eq("card_set_missing")
    end

    it "player_cards に card_seq 列があれば、その列で当てる（列が無ければ使わない）" do
      stub = create(:player_card, card_set: pm2027)
      allow(described_class).to receive(:seq_column?).and_return(true)
      allow(PlayerCard).to receive(:find_by).and_call_original
      allow(PlayerCard).to receive(:find_by).with(card_seq: 42).and_return(stub)

      expect(described_class.locate(row("card_seq" => "42", "name" => "名前では当たらない")).card).to eq(stub)
    end

    it "card_seq 列で見つからなければ、列が無い時と同じ引き方に戻る" do
      player = create(:player, name: "あり")
      card = create(:player_card, player: player, card_set: pm2027)
      allow(described_class).to receive(:seq_column?).and_return(true)
      allow(PlayerCard).to receive(:find_by).and_call_original
      allow(PlayerCard).to receive(:find_by).with(card_seq: 7).and_return(nil)

      expect(described_class.locate(row("card_seq" => "7", "name" => "あり")).card).to eq(card)
    end
  end

  describe ".audit" do
    it "全行を当てて、漏れ・食い違い・同じカードへの重複を数える" do
      a = create(:player, name: "A")
      card_a = create(:player_card, player: a, card_set: pm2027, irc_macro_name: "1")
      b = create(:player, name: "B")
      create(:player_card, player: b, card_set: pm2027, speed: 3, irc_macro_name: "2")

      rows = [
        row("card_seq" => "1", "name" => "A", "irc_macro_name" => "1", "speed" => "3", "bunt" => "5", "steal_start" => "10", "steal_end" => "10", "injury_rate" => "3"),
        row("card_seq" => "2", "name" => "A", "irc_macro_name" => "1", "speed" => "3", "bunt" => "5", "steal_start" => "10", "steal_end" => "10", "injury_rate" => "3"), # A に重複
        row("card_seq" => "3", "name" => "B", "irc_macro_name" => "2", "speed" => "9", "bunt" => "5", "steal_start" => "10", "steal_end" => "10", "injury_rate" => "3"), # speed 食い違い
        row("card_seq" => "4", "name" => "誰か")
      ]
      result = described_class.audit(rows)

      expect(result.slice(:total, :found)).to eq(total: 4, found: 3)
      expect(result[:missing].map { |m| m[:card_seq] }).to eq([ "4" ])
      expect(result[:collisions]).to eq([ { card_id: card_a.id, card_seqs: %w[1 2] } ])
      expect(result[:mismatched].map { |m| [ m[:card_seq], m[:fields] ] }).to eq([ [ "3", [ "speed" ] ] ])
    end
  end
end
