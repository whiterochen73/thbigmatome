require "rails_helper"

# 同じキャラクターの鍵（cmd_1893/subtask_1893e）。
# Test Basis: Operator 裁定（2026-11-14）「エイプリル・完走カードは年度版とは別カードだが同キャラの制限は受ける」
# 「冴月 麟の投手カードと野手カード（別の Player）も同じキャラ」「数字の添え字（Aal と Aal (2)）は別人のカード」
RSpec.describe "Player の同キャラの鍵" do
  def key(name) = create(:player, name: name).character_key

  it "名前の空白（半角・全角）を除いた形が鍵になる" do
    expect(key("八雲 紫")).to eq("八雲紫")
    expect(key("八雲　紫")).to eq("八雲紫")
  end

  it "末尾の丸括弧の添え字は除く（半角・全角の括弧、括弧の前の空白あり・なし）" do
    expect(key("八雲 紫 (エイプリル)")).to eq("八雲紫")
    expect(key("冴月 麟 (投手)")).to eq("冴月麟")
    expect(key("冴月 麟 (野手)")).to eq("冴月麟")
    expect(key("西行寺 幽々子(楼閣)")).to eq("西行寺幽々子")
    expect(key("八雲 藍 (WBC2)")).to eq("八雲藍")
    expect(key("川崎 稜 (1年)")).to eq("川崎稜")
    expect(key("八雲 紫（エイプリル）")).to eq("八雲紫")
  end

  it "数字だけの添え字は別人なので残す（Aal と Aal (2)、mori (2) と mori (3)）" do
    expect(key("Aal")).to eq("Aal")
    expect(key("Aal (2)")).to eq("Aal(2)")
    expect(key("mori (2)")).not_to eq(key("mori (3)"))
    expect(key("坂田 ネムノ (２)")).to eq("坂田ネムノ(２)")
  end

  it "名前を変えると鍵も変わる" do
    pl = create(:player, name: "八雲 紫")
    pl.update!(name: "八雲 藍")
    expect(pl.character_key).to eq("八雲藍")
  end
end
