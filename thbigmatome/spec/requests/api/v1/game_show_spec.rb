require "rails_helper"

# Test Basis: cmd_1812 試合日ページ上の段（相手の短縮形・予告先発の選手名を GET /api/v1/game/:id で返す）
RSpec.describe "GET /api/v1/game/:id（上の段に出す名前）", type: :request, pitcher_fatigue: true do
  include_context "authenticated user"

  let(:team_and_season) { create_team_with_season }
  let(:season) { team_and_season[1] }

  def head_of(schedule)
    get "/api/v1/game/#{schedule.id}", as: :json
    expect(response).to have_http_status(:ok)
    response.parsed_body
  end

  it "相手の短縮形と、予告先発の選手名（背番号なし）を返す。相手の正式名はこれまでどおり返す" do
    opponent = create(:team, name: "命懸ヶ丘高校", short_name: "命懸")
    pitcher, membership = create_card_pitcher(team: team_and_season[0], starter_stamina: 7)
    pitcher.update!(name: "古明地 さとり", number: "18")
    schedule = create(:season_schedule, season: season, date: "2026-05-07",
                                        opponent_team: opponent, announced_starter: membership)

    json = head_of(schedule)

    expect(json["opponent_team_short_name"]).to eq("命懸")
    expect(json["opponent_team"]).to eq("命懸ヶ丘高校")
    expect(json["announced_starter_name"]).to eq("古明地 さとり")
  end

  it "短縮形が空のチームは、正式名を返す（nil・空文字のどちらも）" do
    { nil => "2026-05-08", "" => "2026-05-09" }.each do |blank, date|
      opponent = create(:team, name: "短縮形なし学園", short_name: blank)
      schedule = create(:season_schedule, season: season, date: date, opponent_team: opponent)

      expect(head_of(schedule)["opponent_team_short_name"]).to eq("短縮形なし学園")
    end
  end

  it "相手も予告先発も決まっていない日は、どちらも nil（キーは返す）" do
    schedule = create(:season_schedule, season: season, date: "2026-05-12")

    json = head_of(schedule)

    expect(json).to include("opponent_team_short_name" => nil, "announced_starter_name" => nil)
  end

  it "相手だけ決まっている日は、予告先発だけ nil" do
    opponent = create(:team, short_name: "若尊")
    schedule = create(:season_schedule, season: season, date: "2026-05-08", opponent_team: opponent)

    expect(head_of(schedule)).to include("opponent_team_short_name" => "若尊", "announced_starter_name" => nil)
  end

  # Test Basis: cmd_1814 相手名を押して相手の同じ日の試合日ページへ飛ぶ。相手側のその日の日程の id を返す
  describe "相手側の同じ日の日程（opponent_schedule_id）" do
    let(:own_team) { team_and_season[0] }
    let(:opponent) { create(:team, short_name: "命懸") }
    let(:opponent_season) { create(:season, team: opponent) }
    let(:own_schedule) do
      create(:season_schedule, season: season, date: "2026-05-07", opponent_team: opponent)
    end

    it "相手のシーズンの同じ日で、相手が自チームになっている日程の id を返す" do
      mirror = create(:season_schedule, season: opponent_season, date: "2026-05-07", opponent_team: own_team)

      expect(head_of(own_schedule)["opponent_schedule_id"]).to eq(mirror.id)
    end

    it "相手の同じ日に別のチームとの日程もある時は、自チームとの日程を優先する（別のチームとの日程のほうが先に作られていても）" do
      other_team = create(:team)
      create(:season_schedule, season: opponent_season, date: "2026-05-07", opponent_team: other_team)
      mirror = create(:season_schedule, season: opponent_season, date: "2026-05-07", opponent_team: own_team)

      expect(head_of(own_schedule)["opponent_schedule_id"]).to eq(mirror.id)
    end

    it "相手の同じ日の日程が別のチームとのものだけなら nil（別の試合へは飛ばさない）" do
      create(:season_schedule, season: opponent_season, date: "2026-05-07", opponent_team: create(:team))

      expect(head_of(own_schedule)["opponent_schedule_id"]).to be_nil
    end

    it "相手の同じ日の日程の相手が未定なら nil（同じ試合かどうか分からない）" do
      create(:season_schedule, season: opponent_season, date: "2026-05-07", opponent_team: nil)

      expect(head_of(own_schedule)["opponent_schedule_id"]).to be_nil
    end

    it "相手のシーズンに同じ日の日程が無ければ nil（別の日の自チームとの日程は選ばない）" do
      create(:season_schedule, season: opponent_season, date: "2026-05-08", opponent_team: own_team)

      expect(head_of(own_schedule)["opponent_schedule_id"]).to be_nil
    end

    it "相手にシーズンが無ければ nil" do
      expect(opponent.season).to be_nil
      expect(head_of(own_schedule)["opponent_schedule_id"]).to be_nil
    end

    it "相手が未定なら nil（キーは返す）" do
      schedule = create(:season_schedule, season: season, date: "2026-05-12")

      expect(head_of(schedule)).to include("opponent_schedule_id" => nil)
    end

    it "他チームのシーズンの日程は、相手のものでも自チームのものでも選ばれない（第三者のシーズンの同じ日は無関係）" do
      third_season = create(:season, team: create(:team))
      create(:season_schedule, season: third_season, date: "2026-05-07", opponent_team: own_team)

      expect(head_of(own_schedule)["opponent_schedule_id"]).to be_nil
    end

    it "PUT で相手を保存した応答にも入る（保存した直後の画面が飛び先を取り直さずに済む）" do
      mirror = create(:season_schedule, season: opponent_season, date: "2026-05-07", opponent_team: own_team)
      schedule = create(:season_schedule, season: season, date: "2026-05-07")

      put "/api/v1/game/#{schedule.id}", params: { opponent_team_id: opponent.id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("opponent_schedule_id" => mirror.id)
    end
  end

  describe "PUT（保存した直後の画面が同じ名前を取り直さずに使えるよう、同じ 2 つを返す）" do
    it "相手と予告先発を保存した応答に、短縮形と選手名が入る" do
      opponent = create(:team, short_name: "足立")
      _pitcher, membership = create_card_pitcher(team: team_and_season[0], starter_stamina: 7)
      schedule = create(:season_schedule, season: season, date: "2026-05-10")

      put "/api/v1/game/#{schedule.id}",
          params: { opponent_team_id: opponent.id, announced_starter_id: membership.id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "opponent_team_short_name" => "足立",
        "announced_starter_name" => membership.player.name
      )
    end

    it "相手を外して保存すると nil に戻る" do
      opponent = create(:team, short_name: "足立")
      schedule = create(:season_schedule, season: season, date: "2026-05-10", opponent_team: opponent)

      put "/api/v1/game/#{schedule.id}", params: { opponent_team_id: nil }, as: :json

      expect(response.parsed_body).to include("opponent_team_short_name" => nil)
    end
  end
end
