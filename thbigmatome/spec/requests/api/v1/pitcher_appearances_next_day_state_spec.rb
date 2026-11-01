require "rails_helper"

# Test Basis: cmd_1806 / subtask_1806a（Operator 2026-11-02）。試合日ページの登板記録に「登板による変化」を出す。
# リリーフ・オープナーは「翌日時点の累積イニング」を、保存した登板から求めて返す（画面で計算し直さない）。
# 累積の加算・減衰・中10日リセット・負傷控除は rulebook 08 §8.3.2 / §8.6 のとおり PitcherRestStatus.cumulative_innings と同じ計算。
# 境界: 先発（持たない）・前日までの累積が閾値（3）をまたぐ・休養日の減衰・中10日リセット・負傷控除・0アウト降板・同日の複数投手・登板なしの日。
RSpec.describe "GET /api/v1/pitcher_appearances の next_day_cumulative_innings", type: :request, pitcher_fatigue: true do
  include_context "authenticated user"

  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }
  let!(:starter) { create_card_pitcher(team: team, starter_stamina: 7)[0] }
  let!(:reliever) { create_card_pitcher(team: team, starter_stamina: nil, relief_stamina: 1)[0] }

  def relieve(pitcher, date, innings: 1.0, role: "reliever", no_out_exit: false, order: 1, game: nil)
    create_start(team: team, pitcher: pitcher, date: date, innings: innings, role: role, no_out_exit: no_out_exit,
                 appearance_order: order, game: game)
  end

  def appearances_on(date)
    get "/api/v1/pitcher_appearances", params: { team_id: team.id, schedule_date: date }
    expect(response).to have_http_status(:ok)
    response.parsed_body.index_by { |r| r["pitcher_id"] }
  end

  def next_day(pitcher, date)
    appearances_on(date).fetch(pitcher.id)["next_day_cumulative_innings"]
  end

  it "先発には持たせない（null）。リリーフは登板した回数ぶんの累積を返す" do
    game = create(:game)
    create_start(team: team, pitcher: starter, date: "2026-06-10", innings: 5.0, game: game)
    relieve(reliever, "2026-06-10", innings: 1.0, game: game)
    rows = appearances_on("2026-06-10")
    expect(rows[starter.id]["next_day_cumulative_innings"]).to be_nil
    expect(rows[reliever.id]["next_day_cumulative_innings"]).to eq(1)
  end

  it "先発の後に 2 つの回にまたがって投げたリリーフは、関与イニング（2）を返す" do
    game = create(:game)
    create_start(team: team, pitcher: starter, date: "2026-06-10", innings: 5.2, game: game)
    relieve(reliever, "2026-06-10", innings: 1.1, game: game)
    expect(next_day(reliever, "2026-06-10")).to eq(2)
  end

  it "オープナーもリリーフと同じく累積に数える" do
    relieve(reliever, "2026-06-10", innings: 1.0, role: "opener", order: 0)
    expect(next_day(reliever, "2026-06-10")).to eq(1)
  end

  describe "前日までの累積を引き継ぐ" do
    it "連日登板: 累積 2 のところへ 1 加算して翌日は 3" do
      relieve(reliever, "2026-06-08")
      relieve(reliever, "2026-06-09")
      relieve(reliever, "2026-06-10")
      expect(next_day(reliever, "2026-06-10")).to eq(3)
    end

    it "累積 3 のところへ 1 加算すると翌日は 4（3 を超えても加算は止まらない）" do
      relieve(reliever, "2026-06-07")
      relieve(reliever, "2026-06-08")
      relieve(reliever, "2026-06-09")
      relieve(reliever, "2026-06-10")
      expect(next_day(reliever, "2026-06-10")).to eq(4)
    end

    it "1 日休んだ登板は、休んだ日の減衰（累積 1 → 0）を引いてから加算するので翌日は 1" do
      relieve(reliever, "2026-06-08")
      relieve(reliever, "2026-06-10")
      expect(next_day(reliever, "2026-06-10")).to eq(1)
    end

    it "累積 3 から 1 日休むと 1 まで戻って（3 以下は 1 日 -2）翌日は 2、累積 4 から 1 日休むと 3 まで戻って（4 以上は 1 日 -1）翌日は 4" do
      %w[2026-06-01 2026-06-02 2026-06-03].each { |d| relieve(reliever, d) }
      relieve(reliever, "2026-06-05")
      expect(next_day(reliever, "2026-06-05")).to eq(2)

      other = create_card_pitcher(team: team, starter_stamina: nil, relief_stamina: 1)[0]
      %w[2026-06-01 2026-06-02 2026-06-03 2026-06-04].each { |d| relieve(other, d) }
      relieve(other, "2026-06-06")
      expect(next_day(other, "2026-06-06")).to eq(4)
    end

    it "実日数で中10日空くと全快（累積 0）に戻り、その日の登板だけが累積になる" do
      %w[2026-06-01 2026-06-02 2026-06-03].each { |d| relieve(reliever, d) }
      relieve(reliever, "2026-06-14")
      expect(next_day(reliever, "2026-06-14")).to eq(1)
    end

    it "負傷で離脱していた日は減衰しない（離脱が登板の間の休養日を打ち消す）" do
      relieve(reliever, "2026-06-01")
      membership = TeamMembership.find_by!(team: team, player: reliever)
      create(:player_absence, team_membership: membership, season: season, absence_type: :injury,
                              start_date: Date.new(2026, 6, 2), duration: 3, duration_unit: "days")
      relieve(reliever, "2026-06-05")
      expect(next_day(reliever, "2026-06-05")).to eq(2)
    end

    it "出場停止は休養日を打ち消さない（負傷だけが減衰を止める。AMB-04）" do
      relieve(reliever, "2026-06-01")
      membership = TeamMembership.find_by!(team: team, player: reliever)
      create(:player_absence, team_membership: membership, season: season, absence_type: :suspension,
                              start_date: Date.new(2026, 6, 2), duration: 3, duration_unit: "days")
      relieve(reliever, "2026-06-05")
      expect(next_day(reliever, "2026-06-05")).to eq(1)
    end

    it "その日より後の登板は、翌日の累積に入れない" do
      relieve(reliever, "2026-06-10")
      relieve(reliever, "2026-06-11")
      expect(next_day(reliever, "2026-06-10")).to eq(1)
    end

    it "先発として投げた日は累積に入れない（先発→リリーフの翌日は、リリーフ 1 回ぶんだけ）" do
      create_start(team: team, pitcher: reliever, date: "2026-06-09", innings: 6.0)
      relieve(reliever, "2026-06-10")
      expect(next_day(reliever, "2026-06-10")).to eq(1)
    end
  end

  it "0 アウト降板は次の回に入ったとみなして +1（0.0 回でも 1 以上）" do
    relieve(reliever, "2026-06-10", innings: 0.0, no_out_exit: true)
    expect(next_day(reliever, "2026-06-10")).to eq(1)
    other = create_card_pitcher(team: team, starter_stamina: nil, relief_stamina: 1)[0]
    relieve(other, "2026-06-10", innings: 1.0, no_out_exit: true, order: 2)
    expect(next_day(other, "2026-06-10")).to eq(2)
  end

  it "登板なしの日は空配列を返す" do
    get "/api/v1/pitcher_appearances", params: { team_id: team.id, schedule_date: "2026-06-10" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq([])
  end

  it "fatigue_summary の翌日の累積（cumulative_innings）と同じ値になる（計算の出どころが同じ）" do
    %w[2026-06-08 2026-06-09 2026-06-10].each { |d| relieve(reliever, d) }
    team.update!(user: user)
    get "/api/v1/teams/#{team.id}/pitcher_game_states", params: { date: "2026-06-11", player_ids: [ reliever.id ] }
    expect(response.parsed_body.first["cumulative_innings"]).to eq(next_day(reliever, "2026-06-10"))
  end

  describe "クエリ数" do
    def count_queries
      count = 0
      callback = lambda do |*, payload|
        count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:sql].match?(/\A\s*(BEGIN|COMMIT|SAVEPOINT|RELEASE)/i)
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
      count
    end

    it "同じ日に投げたリリーフの人数が増えても、問い合わせの数は増えない（N+1 にしない）" do
      game = create(:game)
      create_start(team: team, pitcher: starter, date: "2026-06-10", innings: 5.0, game: game)
      relieve(reliever, "2026-06-09")
      relieve(reliever, "2026-06-10", game: game)
      get "/api/v1/pitcher_appearances", params: { team_id: team.id, schedule_date: "2026-06-10" }
      one = count_queries { get "/api/v1/pitcher_appearances", params: { team_id: team.id, schedule_date: "2026-06-10" } }

      extra = Array.new(4) { create_card_pitcher(team: team, starter_stamina: nil, relief_stamina: 1)[0] }
      extra.each_with_index do |pitcher, i|
        relieve(pitcher, "2026-06-08")
        relieve(pitcher, "2026-06-09", order: 0)
        relieve(pitcher, "2026-06-10", order: i + 2, game: game)
      end
      get "/api/v1/pitcher_appearances", params: { team_id: team.id, schedule_date: "2026-06-10" }
      many = count_queries { get "/api/v1/pitcher_appearances", params: { team_id: team.id, schedule_date: "2026-06-10" } }
      expect(response.parsed_body.size).to eq(6)
      expect(many).to eq(one)
    end
  end
end
