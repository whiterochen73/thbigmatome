require "rails_helper"

# cmd_1783 段B: SeasonSchedule#pitcher_appearance_count（一覧から値が入っていない時は、その試合日の分だけ求める）
RSpec.describe SeasonSchedule, "#pitcher_appearance_count" do
  let(:team) { create(:team) }
  let(:season) { create(:season, team: team) }
  let(:competition) { create(:competition) }
  let(:schedule) { create(:season_schedule, season: season, date: Date.new(2026, 5, 7)) }

  def create_appearance(team:, schedule_date:)
    game = create(:game, competition: competition, home_team: team, visitor_team: create(:team))
    create(:pitcher_game_state, team: team, competition: competition, game: game, schedule_date: schedule_date)
  end

  it "登板記録が無ければ 0" do
    expect(schedule.pitcher_appearance_count).to eq(0)
  end

  it "この試合日の自チームの登板記録だけを数える（他チーム・別の日は数えない）" do
    create_appearance(team: team, schedule_date: "2026-05-07")
    create_appearance(team: team, schedule_date: "2026-05-07")
    create_appearance(team: team, schedule_date: "2026-05-08")
    create_appearance(team: create(:team), schedule_date: "2026-05-07")

    expect(schedule.pitcher_appearance_count).to eq(2)
  end

  it "一覧側が入れた値があれば、それを返す（問い合わせない）" do
    schedule.pitcher_appearance_count = 7
    expect(schedule.pitcher_appearance_count).to eq(7)
  end

  it "SeasonScheduleSerializer 単体でも pitcher_appearance_count を返す" do
    create_appearance(team: team, schedule_date: "2026-05-07")
    json = JSON.parse(SeasonScheduleSerializer.new(schedule).to_json)
    expect(json["pitcher_appearance_count"]).to eq(1)
  end
end
