require "rails_helper"

# Test Basis: cmd_1775 Operator 裁定追加 2026-10-25（前回リリーフ→今回先発にも §8.3.4 の補正）/ §8.2.4 関与イニング
RSpec.describe PitcherResultCategory, :pitcher_fatigue do
  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }

  def categorize(pitcher, innings, date: "2026-06-06", game_result: "lose", **extra)
    described_class.call(
      team_id: team.id, pitcher_id: pitcher.id, schedule_date: date, role: "starter",
      innings_pitched: innings, no_out_exit: false, decision: nil, pitchers_in_game: 1, prior_outs: 0,
      game_result: game_result, **extra
    )
  end

  it "通常選手 P6・前回リリーフから中4日 → 疲労P3: 負け試合で関与4 → normal、関与5 → long_loss" do
    pitcher, = create_card_pitcher(team: team, starter_stamina: 6)
    create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 2.0, role: "reliever")

    four = categorize(pitcher, 4.0)
    five = categorize(pitcher, 5.0)
    expect([ four.fatigue_p, four.category ]).to eq([ 3, "normal" ])
    expect([ five.fatigue_p, five.category ]).to eq([ 3, "long_loss" ])
  end

  it "同じ条件でも勝ちなら関与5でも normal" do
    pitcher, = create_card_pitcher(team: team, starter_stamina: 6)
    create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 2.0, role: "reliever")
    expect(categorize(pitcher, 5.0, game_result: "win").category).to eq("normal")
  end

  it "疲労P を特定できない(カード未紐づけ)先発の負け・5回は判定保留(category nil)で pending_reason が付く" do
    pitcher, = create_card_pitcher(team: team, starter_stamina: 6, with_card: false)
    res = categorize(pitcher, 5.0)
    expect(res).to be_pending
    expect(res.pending_reason).to eq(:card_not_identified)
  end
end
