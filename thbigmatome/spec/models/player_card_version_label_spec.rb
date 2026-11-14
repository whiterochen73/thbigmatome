require "rails_helper"

# 同じ選手の別のカードを見分ける印（cmd_1901）。
#
# Test Basis: Operator 指示（2026-11-14）「バリエーション選択の時、完走カードはチーム名で区別できるように。AP と被ることもある」
#   variant（エイプリル・UR・チーム名）があればそれ。無ければカード上部の帯のチーム名・印（team_label）。帯が GLADIATS の通常カードはどちらも持たず nil
RSpec.describe PlayerCard, "#version_label" do
  it "variant があれば variant を返す（team_label があっても variant が先）" do
    expect(build(:player_card, variant: "エイプリル", team_label: "東方PROJECT").version_label).to eq("エイプリル")
    expect(build(:player_card, variant: "飯能").version_label).to eq("飯能")
  end

  it "variant が無く team_label があれば team_label を返す" do
    expect(build(:player_card, variant: nil, team_label: "永山").version_label).to eq("永山")
  end

  it "variant が空文字でも team_label へ落ちる（取り込みは空を nil にするが、手で入れた空文字も同じ扱い）" do
    expect(build(:player_card, variant: "", team_label: "北堀江").version_label).to eq("北堀江")
  end

  it "どちらも無ければ nil（GLADIATS の通常カード）" do
    expect(build(:player_card, variant: nil, team_label: nil).version_label).to be_nil
    expect(build(:player_card, variant: "", team_label: "").version_label).to be_nil
  end

  it "同じ選手の同じセットに、variant 違い・team_label 違いのカードが並んでも区別できる（八雲 紫 の PM2027 の形）" do
    player = create(:player)
    set = create(:card_set)
    ap = create(:player_card, player: player, card_set: set, card_type: "pitcher", variant: "エイプリル")
    hanno = create(:player_card, player: player, card_set: set, card_type: "pitcher", variant: "飯能")
    tsukushino = create(:player_card, player: player, card_set: set, card_type: "pitcher", variant: "筑紫野")
    expect([ ap, hanno, tsukushino ].map(&:version_label)).to eq(%w[エイプリル 飯能 筑紫野])
  end
end
