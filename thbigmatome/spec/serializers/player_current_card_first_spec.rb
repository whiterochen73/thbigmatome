require "rails_helper"

# 1 人の選手が現行セットと現行外のセットの両方のカードを持つ時は、現行セットのカードを先に・既定で見せる（cmd_1893/subtask_1893e）。
# Test Basis: Operator 裁定（2026-11-14）3.「1 人の選手が両方のセットのカードを持つときは、現行セットのほうを見せる」
RSpec.describe "現行セットのカードを先に見せる" do
  let(:player) { create(:player) }
  let(:old_set) { create(:card_set, is_current: false) }
  let(:cur_set) { create(:card_set) }
  # id 順では現行外のカードが先（古いセットから先に取り込まれるため）
  let!(:old_card) { create(:player_card, player: player, card_set: old_set, card_type: "batter", handedness: "right_throw/right_bat") }
  let!(:cur_card) { create(:player_card, player: player, card_set: cur_set, card_type: "batter", handedness: "left_throw/left_bat") }

  it "Player#default_card は現行セットのカード（現行が複数なら id の若い方、現行が無ければ id の若い方）" do
    expect(old_card.id).to be < cur_card.id
    expect(player.reload.default_card).to eq(cur_card)
    expect(create(:player).default_card).to be_nil
    only_old = create(:player)
    first = create(:player_card, player: only_old, card_set: old_set)
    create(:player_card, player: only_old, card_set: old_set, card_type: "pitcher")
    expect(only_old.reload.default_card).to eq(first)
  end

  it "PlayerSerializer の利き手は既定のカード（現行セット）のもの" do
    json = PlayerSerializer.new(Player.eager_load(player_cards: :card_set).find(player.id)).as_json
    expect(json[:handedness]).to eq("left_throw/left_bat")
  end

  it "選手詳細の player_cards は現行セットのカードが先に並ぶ" do
    json = PlayerDetailSerializer.new(Player.includes(player_cards: :card_set).find(player.id)).as_json
    expect(json[:player_cards].map { |c| c[:id] }).to eq([ cur_card.id, old_card.id ])
  end

  it "カードセットの応答に現行の印が入る" do
    expect(CardSetSerializer.new(cur_set).as_json[:is_current]).to be(true)
    expect(CardSetSerializer.new(old_set).as_json[:is_current]).to be(false)
  end
end
