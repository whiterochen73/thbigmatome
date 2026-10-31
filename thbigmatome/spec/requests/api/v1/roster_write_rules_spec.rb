require "rails_helper"

# Test Basis: context/thbig-dugout-season-record-restructure-design.md §4.4（書き込みの規則 1〜4）・§4.1（時点の区分）・§5.1 段1、
# 同 末尾の Operator 決定（過去日の訂正を許す。後の日付を検査し直し、通る時だけ保存）、裁定台帳 AMB-24（昇降格は日による制限なし。クールダウン 10 日のみ）。
# 境界は数値で固定する（定数を参照しない）: 1軍の下限 25 人（24/25）・上限 29 人（29/30）、クールダウン 10 日（9/10）。
RSpec.describe "昇降格の書き込みの規則（日付・区分・検査し直し）", type: :request do
  let(:team) { create(:team) }
  let(:cost) { create(:cost, end_date: nil) }
  let(:season) { create(:season, team: team, current_date: Date.new(2026, 5, 15)) }
  let(:start_day) { Date.new(2026, 4, 1) }

  # シーズン初日(4/1)・5/10・5/20 が試合日。5/5・5/12・5/15 は試合のない日
  before do
    [ "2026-04-01", "2026-05-10", "2026-05-20" ].each do |date|
      create(:season_schedule, season: season, date: date, date_type: "game_day")
    end
  end

  # first_since を渡すとその日の試合前に昇格した記録を足す
  def add_player(first_since: nil, cost_value: 4)
    player = create(:player)
    membership = create(:team_membership, team: team, player: player, squad: first_since ? "first" : "second",
                                           selected_cost_type: "normal_cost", first_since: first_since)
    create(:cost_player, cost: cost, player: player, normal_cost: cost_value)
    membership
  end

  def add_firsts(count, cost_value: 4)
    Array.new(count) { add_player(first_since: start_day, cost_value: cost_value) }
  end

  def record(membership, squad, on, phase: "pre_game")
    create(:season_roster, season: season, team_membership: membership, squad: squad, registered_on: on, phase: phase)
  end

  def post_roster(updates, date: nil, phase: nil)
    params = { roster_updates: updates }
    params[:target_date] = date.to_s if date
    params[:phase] = phase if phase
    post "/api/v1/teams/#{team.id}/roster", params: params, as: :json
  end

  def move(membership, squad)
    { team_membership_id: membership.id, squad: squad }
  end

  def violations
    response.parsed_body["violations"]
  end

  context "一般ユーザー" do
    include_context "authenticated user"
    before { team.update!(user: user) }

    describe "過去日の差し込みで、後の試合日の 1軍人数が下限(25)を割る" do
      it "後の試合日が 24 人になる差し込みは止め、違反した日付を返す" do
        firsts = add_firsts(25)

        expect { post_roster([ move(firsts.first, "second") ], date: Date.new(2026, 5, 5)) }.not_to change(SeasonRoster, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["error"]).to include("2026-05-10")
        expect(violations.first).to include("date" => "2026-05-10", "kind" => "first_squad_min")
        expect(violations.map { |v| v["date"] }).to eq(%w[2026-05-10 2026-05-20])
        expect(firsts.first.reload.squad).to eq("first")
      end

      it "後の試合日が 25 人に留まる差し込みは通る" do
        firsts = add_firsts(26)

        post_roster([ move(firsts.first, "second") ], date: Date.new(2026, 5, 5))

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["warnings"]).to eq([])
        expect(SeasonRoster.where(team_membership: firsts.first).order(:id).last)
          .to have_attributes(squad: "second", registered_on: Date.new(2026, 5, 5), phase: "pre_game")
      end

      it "書き込んだ日が試合日で 24 人になる場合は、これまでどおり止める（対象日は絶対の基準）" do
        firsts = add_firsts(25)

        post_roster([ move(firsts.first, "second") ], date: Date.new(2026, 5, 10))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["error"]).to eq("試合日には1軍に最低25人を登録する必要があります。")
      end
    end

    describe "過去日の差し込みで、後の日付の 1軍人数が上限(29)を超える" do
      it "後の日付が 30 人になる差し込みは止める" do
        add_firsts(28)
        later = add_player
        record(later, "first", Date.new(2026, 5, 10)) # 5/10 から 29 人
        target = add_player

        post_roster([ move(target, "first") ], date: Date.new(2026, 5, 5))

        expect(response).to have_http_status(:unprocessable_content)
        expect(violations.first).to include("date" => "2026-05-10", "kind" => "first_squad_max")
        expect(response.parsed_body["error"]).to include("29人")
        expect(target.reload.squad).to eq("second")
      end

      it "後の日付が 29 人に留まる差し込みは通る" do
        add_firsts(28)
        target = add_player

        post_roster([ move(target, "first") ], date: Date.new(2026, 5, 5))

        expect(response).to have_http_status(:ok)
        expect(target.reload.squad).to eq("first")
      end
    end

    describe "過去日の差し込みで、後の日付の 1軍コストが人数別の上限を超える" do
      # 27 人 × 4 = 108。5/10 から 29 人目の選手が入る。29 人の上限は 120 なので、差し込む選手のコストは 8 まで
      def scenario(cost_value)
        add_firsts(27)
        later = add_player
        record(later, "first", Date.new(2026, 5, 10))
        [ add_player(cost_value: cost_value) ]
      end

      it "差し込む選手のコストが 8 なら後の日付の合計が 120 ちょうどで通る" do
        target = scenario(8).first
        post_roster([ move(target, "first") ], date: Date.new(2026, 5, 5))
        expect(response).to have_http_status(:ok)
      end

      it "コストが 9 なら後の日付の合計が 121 で止める（書き込んだ日 5/5 は 28 人 117 で通る）" do
        target = scenario(9).first
        post_roster([ move(target, "first") ], date: Date.new(2026, 5, 5))
        expect(response).to have_http_status(:unprocessable_content)
        expect(violations.first).to include("date" => "2026-05-10", "kind" => "first_squad_cost")
      end
    end

    describe "クールダウン（降格から 10 日）" do
      let!(:base) { add_firsts(25) }

      it "直接の昇格: 降格から 9 日目(5/10)は止め、10 日目(5/11)は通す" do
        player = add_player(first_since: start_day)
        record(player, "second", Date.new(2026, 5, 1))

        post_roster([ move(player, "first") ], date: Date.new(2026, 5, 10))
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["error"]).to eq("Player #{player.player.name} is on cooldown until 2026-05-11")

        post_roster([ move(player, "first") ], date: Date.new(2026, 5, 11))
        expect(response).to have_http_status(:ok)
      end

      # 5/1 に昇格して同日に降格した選手(同日は免除)が 5/10 に再昇格している。過去(4/1)に昇格を差し込むと、5/1 の降格から 9 日後の再昇格になる
      def same_day_scenario(repromoted_on)
        player = add_player
        record(player, "first", Date.new(2026, 5, 1))
        record(player, "second", Date.new(2026, 5, 1), phase: "post_game")
        record(player, "first", repromoted_on)
        player
      end

      it "後の昇格が降格から 9 日後(5/10)になる差し込みは止め、その昇格の日付を返す" do
        player = same_day_scenario(Date.new(2026, 5, 10))

        post_roster([ move(player, "first") ], date: Date.new(2026, 4, 1))

        expect(response).to have_http_status(:unprocessable_content)
        expect(violations.first).to include("date" => "2026-05-10", "kind" => "cooldown")
        expect(response.parsed_body["error"]).to include(player.player.name)
      end

      it "後の昇格が降格から 10 日後(5/11)なら差し込みは通る" do
        player = same_day_scenario(Date.new(2026, 5, 11))

        post_roster([ move(player, "first") ], date: Date.new(2026, 4, 1))

        expect(response).to have_http_status(:ok)
      end
    end

    describe "保存前から外れていた日は、この保存が悪化させない限り止めない" do
      # 24 人のまま始まったチーム: 5/10・5/20 の試合日は保存の前から下限割れ
      let!(:firsts) { add_firsts(24) }
      let!(:extra) { add_player }

      it "改善する保存(24→25 人)は通る" do
        post_roster([ move(extra, "first") ], date: Date.new(2026, 5, 12))
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["warnings"]).to eq([])
      end

      it "人数が変わらない入れ替え(1 人昇格・1 人抹消)は、下限割れが保存の前からあっても通る" do
        post_roster([ move(extra, "first"), move(firsts.first, "second") ], date: Date.new(2026, 5, 12))
        expect(response).to have_http_status(:ok)
      end

      it "悪化する保存(24→23 人)は、保存の前から外れていた 5/20 でも止める" do
        post_roster([ move(firsts.first, "second") ], date: Date.new(2026, 5, 12))
        expect(response).to have_http_status(:unprocessable_content)
        expect(violations.first).to include("date" => "2026-05-20", "kind" => "first_squad_min")
        expect(firsts.first.reload.squad).to eq("first")
      end
    end

    describe "試合後(post_game)の記録" do
      it "区分を保存し、記録した利用者を残す。同じ日の試合前の状態は変えない" do
        firsts = add_firsts(26)

        post_roster([ move(firsts.first, "second") ], date: Date.new(2026, 5, 10), phase: "post_game")

        expect(response).to have_http_status(:ok)
        entry = SeasonRoster.where(team_membership: firsts.first).order(:id).last
        expect(entry).to have_attributes(phase: "post_game", registered_on: Date.new(2026, 5, 10), recorded_by_user_id: user.id)
        expect(RosterState.at(team, Date.new(2026, 5, 10), "pre_game")[firsts.first.id].squad).to eq("first")
        expect(RosterState.at(team, Date.new(2026, 5, 10), "post_game")[firsts.first.id].squad).to eq("second")
      end

      it "試合日の試合後に 25→24 人になる抹消は、書き込んだ時点では通るが、次の試合日(5/20)の下限割れで止める" do
        firsts = add_firsts(25)

        post_roster([ move(firsts.first, "second") ], date: Date.new(2026, 5, 10), phase: "post_game")

        expect(response).to have_http_status(:unprocessable_content)
        expect(violations.first).to include("date" => "2026-05-20", "kind" => "first_squad_min")
      end

      it "試合前の昇格と同日の試合後の抹消は、続けて保存でき、同日の昇降格は再昇格のクールダウンを免除する" do
        add_firsts(25)
        player = add_player

        post_roster([ move(player, "first") ], date: Date.new(2026, 5, 12), phase: "pre_game")
        post_roster([ move(player, "second") ], date: Date.new(2026, 5, 12), phase: "post_game")
        post_roster([ move(player, "first") ], date: Date.new(2026, 5, 14), phase: "pre_game")

        expect(response).to have_http_status(:ok)
        expect(SeasonRoster.where(team_membership: player).pluck(:squad, :phase))
          .to eq([ %w[first pre_game], %w[second post_game], %w[first pre_game] ])
      end

      it "不正な区分は 422" do
        firsts = add_firsts(26)
        expect { post_roster([ move(firsts.first, "second") ], date: Date.new(2026, 5, 5), phase: "midnight") }.not_to change(SeasonRoster, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe "省略時の既定" do
      it "target_date を省略すると現在日カーソル(5/15)・pre_game で記録する" do
        firsts = add_firsts(26)

        post_roster([ move(firsts.first, "second") ])

        expect(response).to have_http_status(:ok)
        expect(SeasonRoster.where(team_membership: firsts.first).order(:id).last)
          .to have_attributes(registered_on: Date.new(2026, 5, 15), phase: "pre_game")
      end
    end

    describe "写し(team_memberships.squad)の作り直し" do
      it "現在日カーソル(5/15)と違う過去日(5/1)の保存でも写しを更新する" do
        add_firsts(25)
        target = add_player

        post_roster([ move(target, "first") ], date: Date.new(2026, 5, 1))

        expect(response).to have_http_status(:ok)
        expect(target.reload.squad).to eq("first")
      end

      it "現在日カーソルより後の日付(6/1)の保存でも写しは変更記録の最新(first)になる" do
        add_firsts(25)
        target = add_player

        post_roster([ move(target, "first") ], date: Date.new(2026, 6, 1))

        expect(target.reload.squad).to eq("first")
      end

      it "最後の記録より前の日付に降格を差し込んでも、写しは最後の記録(first)のまま" do
        add_firsts(25)
        player = add_player
        record(player, "first", Date.new(2026, 3, 1))
        record(player, "first", Date.new(2026, 5, 1))

        post_roster([ move(player, "second") ], date: Date.new(2026, 3, 25))

        expect(response).to have_http_status(:ok)
        expect(RosterState.at(team, Date.new(2026, 3, 25))[player.id].squad).to eq("second")
        expect(player.reload.squad).to eq("first")
      end

      it "写しが古くて first のままでも、記録が無ければ保存のたびに second へ直る" do
        stale = create(:team_membership, team: team, squad: "first")
        create(:cost_player, cost: cost, player: stale.player, normal_cost: 4)
        firsts = add_firsts(26)

        post_roster([ move(firsts.first, "second") ], date: Date.new(2026, 5, 5))

        expect(stale.reload.squad).to eq("second")
      end
    end

    describe "入力の検査" do
      it "同じ選手の重複は 422（記録なし）" do
        firsts = add_firsts(26)
        expect {
          post_roster([ move(firsts.first, "second"), move(firsts.first, "first") ], date: Date.new(2026, 5, 5))
        }.not_to change(SeasonRoster, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "first/second 以外の squad は 422（記録なし）" do
        firsts = add_firsts(26)
        expect { post_roster([ move(firsts.first, "third") ], date: Date.new(2026, 5, 5)) }.not_to change(SeasonRoster, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["error"]).to include("squad")
      end

      it "他チームの選手は 404（記録なし）" do
        add_firsts(26)
        stranger = create(:team_membership, team: create(:team))
        expect { post_roster([ move(stranger, "first") ], date: Date.new(2026, 5, 5)) }.not_to change(SeasonRoster, :count)
        expect(response).to have_http_status(:not_found)
      end

      it "不正な日付は 422" do
        firsts = add_firsts(26)
        post "/api/v1/teams/#{team.id}/roster", params: { roster_updates: [ move(firsts.first, "second") ], target_date: "not-a-date" }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "同じ内容の二重送信は、2 回目は記録を増やさない" do
        firsts = add_firsts(26)
        post_roster([ move(firsts.first, "second") ], date: Date.new(2026, 5, 5))
        expect { post_roster([ move(firsts.first, "second") ], date: Date.new(2026, 5, 5)) }.not_to change(SeasonRoster, :count)
        expect(response).to have_http_status(:ok)
      end

      it "検査で止めた保存は、同じ要求の中の他の選手の記録も残さない" do
        firsts = add_firsts(25)
        extra = add_player
        expect {
          post_roster([ move(extra, "first"), move(firsts[0], "second"), move(firsts[1], "second") ], date: Date.new(2026, 5, 5))
        }.not_to change(SeasonRoster, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe "GET /teams/:id/roster の日付・区分" do
      it "区分で同じ日の状態が分かれる。省略時は現在日カーソルの pre_game" do
        player = add_player
        record(player, "first", Date.new(2026, 5, 15), phase: "post_game")

        squad = lambda do |query|
          get "/api/v1/teams/#{team.id}/roster#{query}"
          response.parsed_body["roster"].find { |r| r["team_membership_id"] == player.id }["squad"]
        end

        expect(squad.call("")).to eq("second")
        expect(squad.call("?target_date=2026-05-15&phase=pre_game")).to eq("second")
        expect(squad.call("?target_date=2026-05-15&phase=post_game")).to eq("first")
        expect(squad.call("?target_date=2026-05-16")).to eq("first")
        expect(response.parsed_body["current_date"]).to eq("2026-05-16")
      end

      it "クールダウンは降格から 9 日目(5/10)まで残り、10 日目(5/11)で消える（同日免除の印も返す）" do
        player = add_player(first_since: start_day)
        record(player, "second", Date.new(2026, 5, 1))
        row = lambda do |date|
          get "/api/v1/teams/#{team.id}/roster?target_date=#{date}"
          response.parsed_body["roster"].find { |r| r["team_membership_id"] == player.id }
        end

        expect(row.call("2026-05-10")).to include("cooldown_until" => "2026-05-11", "same_day_exempt" => false)
        expect(row.call("2026-05-11")).to include("cooldown_until" => nil, "same_day_exempt" => false)
      end

      it "不正な区分は 400" do
        add_player
        get "/api/v1/teams/#{team.id}/roster?phase=midnight"
        expect(response).to have_http_status(:bad_request)
      end

      it "写しが first でも記録が無ければ 2軍と返す" do
        stale = create(:team_membership, team: team, squad: "first")
        get "/api/v1/teams/#{team.id}/roster"
        expect(response.parsed_body["roster"].find { |r| r["team_membership_id"] == stale.id }["squad"]).to eq("second")
      end
    end
  end

  context "コミッショナー" do
    include_context "authenticated commissioner"

    it "後の試合日が 24 人になる差し込みは、警告つきで保存する（警告に違反した日付を含む）" do
      firsts = add_firsts(25)

      expect { post_roster([ move(firsts.first, "second") ], date: Date.new(2026, 5, 5)) }.to change(SeasonRoster, :count).by(1)

      expect(response).to have_http_status(:ok)
      warning = response.parsed_body["warnings"].find { |w| w["kind"] == "first_squad_min" }
      expect(warning).to include("type" => "commissioner_override", "date" => "2026-05-10", "phase" => "pre_game")
      expect(warning["message"]).to include("2026-05-10")
      expect(firsts.first.reload.squad).to eq("second")
    end

    it "後の昇格がクールダウンに掛かる差し込みも警告つきで保存する" do
      add_firsts(25)
      player = add_player
      record(player, "first", Date.new(2026, 5, 1))
      record(player, "second", Date.new(2026, 5, 1), phase: "post_game")
      record(player, "first", Date.new(2026, 5, 10))

      post_roster([ move(player, "first") ], date: Date.new(2026, 4, 1))

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["warnings"].map { |w| [ w["kind"], w["date"] ] }).to include([ "cooldown", "2026-05-10" ])
    end

    it "書き込んだ日そのものの違反は、日付なしのこれまでの文面で警告する" do
      firsts = add_firsts(25)

      post_roster([ move(firsts.first, "second") ], date: Date.new(2026, 5, 10))

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["warnings"].map { |w| w["message"] }).to include("試合日には1軍に最低25人を登録する必要があります。")
    end

    it "直接の昇格のクールダウンは、コミッショナーでも 9 日目(5/10)は止め、10 日目(5/11)は通す" do
      add_firsts(25)
      player = add_player(first_since: start_day)
      record(player, "second", Date.new(2026, 5, 1))

      post_roster([ move(player, "first") ], date: Date.new(2026, 5, 10))
      expect(response).to have_http_status(:unprocessable_content)

      post_roster([ move(player, "first") ], date: Date.new(2026, 5, 11))
      expect(response).to have_http_status(:ok)
    end
  end
end
