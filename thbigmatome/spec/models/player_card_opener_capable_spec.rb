require "rails_helper"

# 「オープナー可」アビリティ（ability_definitions.name）の有無。rulebook 08 §8.4.1。
# pitcher_game_states.is_opener（登板時のフラグ）とは別物で、こちらはカードが持つアビリティだけを見る。
# ability_definitions が 1 件も無い間（カードの記載が Dugout に未取込）は、リリーフで投げられるカード全員を true にする（Operator 2026-10-27）。
RSpec.describe PlayerCard, "#opener_capable?" do
  let(:card) { create(:player_card, starter_stamina: nil, relief_stamina: 3, is_relief_only: false) }

  def give(card, name)
    definition = AbilityDefinition.find_or_create_by!(name: name)
    PlayerCardAbility.create!(player_card: card, ability_definition: definition)
  end

  describe "定義が 1 件も無い（未取込）" do
    it "リリーフ向けの疲労P を持つカードは true（スラッシュも）" do
      expect(card.opener_capable?).to be true
      expect(create(:player_card, starter_stamina: 7, relief_stamina: 3).opener_capable?).to be true
    end

    it "リリーフ専門のカードは true" do
      expect(create(:player_card, starter_stamina: nil, relief_stamina: 2, is_relief_only: true).opener_capable?).to be true
    end

    it "リリーフ向けの疲労P を持たない先発は false" do
      expect(create(:player_card, starter_stamina: 7, relief_stamina: nil, is_relief_only: false).opener_capable?).to be false
    end

    it "relief_capable? は「リリーフなら」を出す条件（relief_stamina を持つ・リリーフ専門）と同じ" do
      expect(card.relief_capable?).to be true
      expect(create(:player_card, starter_stamina: 7, relief_stamina: nil, is_relief_only: false).relief_capable?).to be false
      expect(create(:player_card, starter_stamina: nil, relief_stamina: nil, is_relief_only: true).relief_capable?).to be true
    end
  end

  describe "定義が 1 件でもある（取込済み）: カードの記載どおり" do
    before { AbilityDefinition.create!(name: "クイック○") }

    it "アビリティを持たないカードは、リリーフで投げられても false" do
      expect(card.reload.opener_capable?).to be false
    end

    it "「オープナー可」を持つカードは true（先発専門でも）" do
      give(card, "オープナー可")
      starter = create(:player_card, starter_stamina: 7, relief_stamina: nil)
      give(starter, "オープナー可")
      expect(card.reload.opener_capable?).to be true
      expect(starter.reload.opener_capable?).to be true
    end

    it "他のアビリティだけ・名前が少し違うもの（「オープナー」「オープナー不可」）は false" do
      %w[クイック○ オープナー オープナー不可].each { |name| give(card, name) }
      expect(card.reload.opener_capable?).to be false
    end

    it "複数のアビリティの中に「オープナー可」があれば true" do
      give(card, "クイック○")
      give(card, "オープナー可")
      expect(card.reload.opener_capable?).to be true
    end

    it "is_opener（登板時のフラグ）の登板があっても、アビリティが無ければ false" do
      team = create(:team)
      competition = create(:competition)
      game = create(:game, competition: competition, home_team: team, visitor_team: create(:team))
      create(:pitcher_game_state, pitcher: card.player, team: team, competition: competition, game: game, role: "opener")
      expect(card.reload.opener_capable?).to be false
    end
  end

  it "定義の有無を引数で渡せる（呼び出し側が 1 リクエストで 1 回だけ問い合わせるため）" do
    expect(card.opener_capable?(false)).to be true  # 定義なし扱い → リリーフ可能なら true
    expect(card.opener_capable?(true)).to be false  # 定義あり扱い → カードの記載どおり（記載なし）
  end
end
