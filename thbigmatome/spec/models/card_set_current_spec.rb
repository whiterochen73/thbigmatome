require "rails_helper"

# 現行カードセットの印（cmd_1893/subtask_1893e）。
# Test Basis: Operator 裁定（2026-11-14）「PM2026 が現行カードセットから外れる」「選手を登録する画面では、現行カードセットのカードだけを選べる。
# 公式戦使用不可のカードも選べない」。現行は PM2027・2025THBIG・hachinai6.1・tamayomi2。
RSpec.describe "CardSet の現行の印" do
  it "列 is_current は null 不可で既定は現行（true）" do
    col = CardSet.columns_hash["is_current"]
    expect(col).to be_present
    expect(col.null).to be(false)
    expect(CardSet.new.is_current).to be(true)
  end

  it "現行の印の向きで CardSet.current が絞れる" do
    now = create(:card_set)
    old = create(:card_set, is_current: false)
    expect(CardSet.current).to include(now)
    expect(CardSet.current).not_to include(old)
  end

  describe "PlayerCard.registrable（登録画面で選べるカード）" do
    let(:player) { create(:player) }

    it "現行セットの、公式戦で使えるカードだけ" do
      cur = create(:player_card, player: player, card_set: create(:card_set))
      old = create(:player_card, player: player, card_set: create(:card_set, is_current: false), card_type: "pitcher")
      banned = create(:player_card, player: player, card_set: cur.card_set, card_type: "pitcher", official_use_prohibited: true)
      expect(PlayerCard.registrable).to contain_exactly(cur)
      expect(cur).to be_registrable
      expect(old).not_to be_registrable
      expect(banned).not_to be_registrable
    end
  end

  describe "取り込みの対応表（config/card_set_definitions.yml）" do
    it "現行は PM2027・2025THBIG・hachinai6.1・tamayomi2、外れるのは PM2026 だけ" do
      defs = CardSet::IMPORT_DEFINITIONS
      expect(defs.keys).to match_array(%w[2025THBIG hachinai6.1 PM2026 PM2027 tamayomi2])
      expect(defs.select { |_, d| d[:current] }.keys).to match_array(%w[2025THBIG hachinai6.1 PM2027 tamayomi2])
      expect(defs.fetch("PM2026")[:current]).to be(false)
    end
  end
end
