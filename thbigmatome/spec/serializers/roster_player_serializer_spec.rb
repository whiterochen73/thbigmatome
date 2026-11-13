require "rails_helper"

# 編成の一覧の利き手は、選手の既定のカード（現行セットのカードを先に）から取る（cmd_1894/subtask_1894a）。
# Test Basis: Operator 裁定 2026-11-14（両方のセットのカードを持つ選手は現行セットのほうを見せる）。Player#default_card と同じ並び。
RSpec.describe RosterPlayerSerializer do
  let(:player) { create(:player) }
  let(:membership) { create(:team_membership, player: player) }

  def handedness_of(tm)
    described_class.new(tm).handedness
  end

  it "id の若い旧セットのカードより、現行セットのカードの利き手を返す" do
    create(:player_card, player: player, card_set: create(:card_set, is_current: false), handedness: "left")
    create(:player_card, player: player, card_set: create(:card_set, is_current: true), handedness: "right")
    expect(handedness_of(membership)).to eq("right")
  end

  it "現行セットのカードだけなら、そのカード" do
    create(:player_card, player: player, card_set: create(:card_set, is_current: true), handedness: "left")
    expect(handedness_of(membership)).to eq("left")
  end

  it "カードの無い選手は nil" do
    expect(handedness_of(membership)).to be_nil
  end
end
