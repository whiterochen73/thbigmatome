require "rails_helper"

# Test Basis: cmd_1896 Operator 裁定（2026-11-14）「日付が書いてある時限選手は、指定の期間のみ登録可能。期間外は起用不可」。
# 「M/D~」= その日から、「~M/D」= その日まで（両端を含む）。バイオリズム列は読まない。
RSpec.describe PlayerCard, "#availability_period / #available_on?" do
  def card(traits, **attrs) = build(:player_card, unique_traits: traits, **attrs)

  describe "パース" do
    it "「4/22~」「5/1~」は開始だけ" do
      expect(card("4/22~").availability_period).to eq(from: [ 4, 22 ], to: nil)
      expect(card("5/1~").availability_period).to eq(from: [ 5, 1 ], to: nil)
    end

    it "実データの改行を含む「~9/24\\n左手突き指」は終了だけ" do
      expect(card("ホームラン\n【専属捕手】\nレイセン\nDB\n~9/24\n左手突き指").availability_period).to eq(from: nil, to: [ 9, 24 ])
    end

    it "全角の〜・～も受ける" do
      expect(card("4/22〜").availability_period).to eq(from: [ 4, 22 ], to: nil)
      expect(card("～9/24").availability_period).to eq(from: nil, to: [ 9, 24 ])
    end

    it "両端がある「4/22~9/24」は両方" do
      expect(card("4/22~9/24").availability_period).to eq(from: [ 4, 22 ], to: [ 9, 24 ])
    end

    it "時限でない・nil・日付を含まない・M/D のない範囲表記は nil" do
      [ nil, "", "ホームラン", "(1~19)\n(20)", "【投手】\n(1~15)\n(16~20)", "出停10試合" ].each do |t|
        expect(card(t).availability_period).to be_nil
        expect(card(t).time_limited?).to be(false)
      end
    end

    it "存在しない月日は無視する" do
      expect(card("2/30~").availability_period).to be_nil
    end

    it "バイオリズムの列だけを持つカードは時限でない" do
      c = card(nil, biorhythm_period: "4/22~9/24", biorhythm_date_ranges: "4/22~")
      expect(c.availability_period).to be_nil
      expect(c.available_on?(Date.new(2026, 1, 1))).to be(true)
    end
  end

  describe "available_on?" do
    let(:anchor) { Date.new(2026, 4, 1) }

    it "「4/22~」: 4/21 は不可、4/22 は可、シーズン終わりまで可" do
      c = card("4/22~")
      expect(c.available_on?(Date.new(2026, 4, 21), anchor: anchor)).to be(false)
      expect(c.available_on?(Date.new(2026, 4, 22), anchor: anchor)).to be(true)
      expect(c.available_on?(Date.new(2026, 10, 30), anchor: anchor)).to be(true)
    end

    it "「~9/24」: 9/24 は可、9/25 は不可、シーズン初日は可" do
      c = card("~9/24\n左手突き指")
      expect(c.available_on?(anchor, anchor: anchor)).to be(true)
      expect(c.available_on?(Date.new(2026, 9, 24), anchor: anchor)).to be(true)
      expect(c.available_on?(Date.new(2026, 9, 25), anchor: anchor)).to be(false)
    end

    it "時限でないカードは常に可" do
      expect(card("ホームラン").available_on?(Date.new(2026, 1, 1), anchor: anchor)).to be(true)
    end

    it "年をまたぐシーズン（12/20 開始）では、「~1/10」は翌年の 1/10 まで・「1/5~」は翌年の 1/5 から" do
      start = Date.new(2026, 12, 20)
      expect(card("~1/10").available_on?(Date.new(2027, 1, 10), anchor: start)).to be(true)
      expect(card("~1/10").available_on?(Date.new(2027, 1, 11), anchor: start)).to be(false)
      expect(card("1/5~").available_on?(Date.new(2027, 1, 4), anchor: start)).to be(false)
      expect(card("1/5~").available_on?(Date.new(2027, 1, 5), anchor: start)).to be(true)
    end
  end
end
