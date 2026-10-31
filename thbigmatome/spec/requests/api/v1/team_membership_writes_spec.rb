require "rails_helper"

# Test Basis: context/thbig-dugout-season-record-restructure-design.md §4.2（変更後の値を丸ごと持つ）・§4.4 の 1（日付と区分を受ける。省略時は現在日カーソル・pre_game）・
# 2（差し込み・削除のあと後の時点を検査し直し、通る時だけ保存。コミッショナーは警告つき）・3（保存のたびに写しを作り直す）・5（送られた値と「その時点の状態」の差を記録にする。
# 外された選手は release。行は消さない）・§5.2 段2（記録が無い行は今の値）、§7 判断 2（過去日の訂正を許す）。
# 境界は数値で固定する（定数を参照しない）: 1軍の下限 25 人・上限 29 人、28 人の 1軍コスト上限 120（120/121）、チーム全体 200（200/201）。
RSpec.describe "チーム編成の保存（変更記録の追加）", type: :request do
  let(:team) { create(:team) }
  let(:cost) { create(:cost, end_date: nil) }
  let(:season) { create(:season, team: team, current_date: Date.new(2026, 5, 15)) }
  let(:start_day) { Date.new(2026, 4, 1) }

  # 合計コストの超過文は ja の文面。テスト環境の既定ロケールは en なので ja に固定して文面を検査する
  around { |example| I18n.with_locale(:ja) { example.run } }

  # シーズン初日(4/1)・5/10・5/20 が試合日。5/5・5/12・5/15 は試合のない日
  before do
    [ "2026-04-01", "2026-05-10", "2026-05-20" ].each do |date|
      create(:season_schedule, season: season, date: date, date_type: "game_day")
    end
  end

  # 記録の無い（移行前の）行。first_since を渡すとその日の試合前に昇格した記録を足す
  def add_player(first_since: nil, cost_value: 4, **attrs)
    player = create(:player)
    membership = create(:team_membership, team: team, player: player, selected_cost_type: "normal_cost", first_since: first_since, **attrs)
    create(:cost_player, cost: cost, player: player, normal_cost: cost_value)
    membership
  end

  def add_firsts(count, cost_value: 4)
    Array.new(count) { add_player(first_since: start_day, cost_value: cost_value) }
  end

  # 全員分の現在の値を送り直す形の params。overrides は player_id => { 上書きする値 }
  def payload(memberships, overrides: {})
    memberships.map do |tm|
      { player_id: tm.player_id, selected_cost_type: tm.selected_cost_type, excluded_from_team_total: tm.excluded_from_team_total,
        display_name: tm.display_name, player_card_id: tm.player_card_id }.merge(overrides.fetch(tm.player_id, {}))
    end
  end

  def new_player_param(player, **values)
    { player_id: player.id, selected_cost_type: "normal_cost", excluded_from_team_total: false, display_name: nil }.merge(values)
  end

  def post_players(players, date: nil, phase: nil, cost_list_id: cost.id)
    params = { players: players, cost_list_id: cost_list_id }
    params[:target_date] = date.to_s if date
    params[:phase] = phase if phase
    post "/api/v1/teams/#{team.id}/team_players", params: params, as: :json
  end

  def changes_of(membership)
    TeamMembershipChange.where(team_membership: membership).order(:effective_on, :id)
  end

  def violations
    response.parsed_body["violations"]
  end

  context "一般ユーザー" do
    include_context "authenticated user"
    before { team.update!(user: user) }

    describe "新しい選手の登録" do
      it "join を現在日カーソル(5/15)・pre_game で 1 件足し、行と写しを作る。2軍で、昇降格の記録は作らない" do
        newcomer = create(:player)
        create(:cost_player, cost: cost, player: newcomer, normal_cost: 5)

        expect { post_players([ new_player_param(newcomer, display_name: "新人") ]) }
          .to change(TeamMembershipChange, :count).by(1).and change(TeamMembership, :count).by(1)

        expect(response).to have_http_status(:ok)
        membership = team.all_team_memberships.find_by!(player: newcomer)
        expect(changes_of(membership).first).to have_attributes(
          kind: "join", effective_on: Date.new(2026, 5, 15), phase: "pre_game", selected_cost_type: "normal_cost",
          display_name: "新人", recorded_by_user_id: user.id, season_id: season.id
        )
        expect(membership).to have_attributes(squad: "second", on_team: true, display_name: "新人")
        expect(SeasonRoster.where(team_membership: membership)).to be_empty
      end

      it "日付と区分を指定すると、その時点で記録する" do
        newcomer = create(:player)
        create(:cost_player, cost: cost, player: newcomer, normal_cost: 5)

        post_players([ new_player_param(newcomer) ], date: Date.new(2026, 5, 1), phase: "post_game")

        membership = team.all_team_memberships.find_by!(player: newcomer)
        expect(changes_of(membership).first).to have_attributes(effective_on: Date.new(2026, 5, 1), phase: "post_game")
      end

      it "カードを指定すると記録にも写しにも入る" do
        newcomer = create(:player)
        card = create(:player_card, player: newcomer)
        create(:cost_player, cost: cost, player: newcomer, normal_cost: 5)

        post_players([ new_player_param(newcomer, player_card_id: card.id) ])

        membership = team.all_team_memberships.find_by!(player: newcomer)
        expect(changes_of(membership).first.player_card_id).to eq(card.id)
        expect(membership.player_card_id).to eq(card.id)
      end
    end

    describe "差が無い保存" do
      it "全員を同じ値で送り直しても記録を増やさない（二重送信）。記録の無い行に初期記録も作らない" do
        members = Array.new(3) { add_player }

        expect { 2.times { post_players(payload(members)) } }.not_to change(TeamMembershipChange, :count)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "契約・カードの変更" do
      it "記録の無い行は、先に今の値で初期の join を足し（最初の昇降格の日とシーズン開始日の早い方）、続けて contract を足す" do
        member = add_player(first_since: Date.new(2026, 4, 20))
        create(:cost_player, cost: cost, player: member.player, normal_cost: 4, relief_only_cost: 2) if false

        post_players(payload([ member ], overrides: { member.player_id => { selected_cost_type: "relief_only_cost", display_name: "転向" } }))

        expect(response).to have_http_status(:ok)
        initial, changed = changes_of(member).to_a
        expect(initial).to have_attributes(kind: "join", effective_on: start_day, selected_cost_type: "normal_cost", display_name: nil)
        expect(changed).to have_attributes(kind: "contract", effective_on: Date.new(2026, 5, 15), selected_cost_type: "relief_only_cost",
                                           display_name: "転向", recorded_by_user_id: user.id)
        expect(member.reload).to have_attributes(selected_cost_type: "relief_only_cost", display_name: "転向")

        state = RosterState.new(team)
        expect(state.at(Date.new(2026, 5, 14)).fetch(member.id)).to have_attributes(selected_cost_type: "normal_cost", display_name: nil)
        expect(state.at(Date.new(2026, 5, 15)).fetch(member.id)).to have_attributes(selected_cost_type: "relief_only_cost", display_name: "転向")
      end

      it "書き込む日が初期の join の日付より前なら、join もその日に置く" do
        member = add_player

        post_players(payload([ member ], overrides: { member.player_id => { excluded_from_team_total: true } }), date: Date.new(2026, 3, 1))

        initial, changed = changes_of(member).to_a
        expect(initial).to have_attributes(kind: "join", effective_on: Date.new(2026, 3, 1), excluded_from_team_total: false)
        expect(changed).to have_attributes(kind: "contract", effective_on: Date.new(2026, 3, 1), excluded_from_team_total: true)
        expect(RosterState.at(team, Date.new(2026, 3, 1)).fetch(member.id).excluded_from_team_total).to be(true)
      end

      it "過去日(5/5)への訂正を許す。その日より前の状態は変わらない" do
        member = add_player

        post_players(payload([ member ], overrides: { member.player_id => { selected_cost_type: "pitcher_only_cost" } }), date: Date.new(2026, 5, 5))

        expect(response).to have_http_status(:ok)
        expect(changes_of(member).last).to have_attributes(kind: "contract", effective_on: Date.new(2026, 5, 5))
        state = RosterState.new(team)
        expect(state.at(Date.new(2026, 5, 4)).fetch(member.id).selected_cost_type).to eq("normal_cost")
        expect(state.at(Date.new(2026, 5, 5)).fetch(member.id).selected_cost_type).to eq("pitcher_only_cost")
      end

      it "不正な契約種別は 422 で、同じ要求の他の選手の記録も残さない" do
        good = add_player
        bad = add_player

        expect do
          post_players(payload([ good, bad ], overrides: { good.player_id => { display_name: "良" }, bad.player_id => { selected_cost_type: "nonsense_cost" } }))
        end.not_to change(TeamMembershipChange, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["error"]).to be_present
        expect(good.reload.display_name).to be_nil
      end
    end

    describe "放出" do
      it "送られなかった在籍中の選手に release を足す。行は消さず、写しの在籍だけ外す" do
        keep = add_player
        leave = add_player

        post_players(payload([ keep ]))

        expect(response).to have_http_status(:ok)
        expect(TeamMembership.exists?(leave.id)).to be(true)
        initial, release = changes_of(leave).to_a
        expect(initial.kind).to eq("join")
        expect(release).to have_attributes(kind: "release", effective_on: Date.new(2026, 5, 15), selected_cost_type: "normal_cost")
        expect(leave.reload.on_team).to be(false)
        expect(team.reload.team_memberships.map(&:id)).to eq([ keep.id ])
        expect(changes_of(keep)).to be_empty
      end

      it "昇降格の記録・離脱の記録がある選手も放出できる（これまで外部キーで失敗していた）" do
        firsts = add_firsts(26)
        leave = firsts.first
        create(:player_absence, team_membership: leave, season: season, start_date: Date.new(2026, 5, 1))

        post_players(payload(firsts.drop(1)))

        expect(response).to have_http_status(:ok)
        expect(TeamMembership.exists?(leave.id)).to be(true)
        expect(leave.season_rosters.count).to eq(2)
        expect(leave.player_absences.count).to eq(1)
      end

      it "1軍の選手を放出すると、同じ時点に 2軍への降格を足す（25 人から 24 人になる試合日があるので、コミッショナー以外は止まる）" do
        firsts = add_firsts(26)

        post_players(payload(firsts.drop(1)))

        expect(response).to have_http_status(:ok)
        expect(SeasonRoster.where(team_membership: firsts.first).order(:id).last)
          .to have_attributes(squad: "second", registered_on: Date.new(2026, 5, 15), phase: "pre_game", recorded_by_user_id: user.id)
        expect(firsts.first.reload).to have_attributes(on_team: false, squad: "second")
      end

      it "放出した日の前の状態は残る（ロスター画面で過去日を開くと在籍している）" do
        keep = add_player
        leave = add_player
        post_players(payload([ keep ]))

        get "/api/v1/teams/#{team.id}/roster", params: { target_date: "2026-05-14" }
        expect(response.parsed_body["roster"].map { |r| r["team_membership_id"] }).to contain_exactly(keep.id, leave.id)

        get "/api/v1/teams/#{team.id}/roster", params: { target_date: "2026-05-15" }
        expect(response.parsed_body["roster"].map { |r| r["team_membership_id"] }).to eq([ keep.id ])
      end

      it "再登録すると join を足して在籍に戻り、2軍から始まる" do
        firsts = add_firsts(26)
        leave = firsts.first
        post_players(payload(firsts.drop(1)), date: Date.new(2026, 5, 1))
        expect(response).to have_http_status(:ok)

        post_players(payload(firsts), date: Date.new(2026, 5, 16))

        expect(response).to have_http_status(:ok)
        expect(changes_of(leave).map(&:kind)).to eq(%w[join release join])
        expect(leave.reload).to have_attributes(on_team: true, squad: "second")
        expect(RosterState.at(team, Date.new(2026, 5, 16)).fetch(leave.id)).to have_attributes(on_team: true, squad: "second")
      end

      it "放出済みの選手の昇降格は記録しない（在籍していない）" do
        keep = add_player
        leave = add_player
        post_players(payload([ keep ]))

        expect { post "/api/v1/teams/#{team.id}/roster", params: { roster_updates: [ { team_membership_id: leave.id, squad: "first" } ] }, as: :json }
          .not_to change(SeasonRoster, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["error"]).to include("在籍していません")
      end
    end

    describe "後の時点の検査し直し" do
      # 28 人 × 4 = 112（28 人の上限は 120）。対象の選手は 5/10 に昇格する記録があり、5/10 の 1軍は 29 人
      def scenario
        add_firsts(28)
        target = add_player
        create(:season_roster, season: season, team_membership: target, squad: "first", registered_on: Date.new(2026, 5, 10))
        target
      end

      it "過去日(5/5)の契約変更で、後の試合日(5/10)の 1軍コストが 121 になるなら止め、違反した日付を返す" do
        target = scenario
        CostPlayer.find_by!(player: target.player).update!(pitcher_only_cost: 9) # 5/10: 112 + 9 = 121 > 120 (29 人の上限は 120)

        post_players(payload(team.all_team_memberships.reload, overrides: { target.player_id => { selected_cost_type: "pitcher_only_cost" } }),
                     date: Date.new(2026, 5, 5))

        expect(response).to have_http_status(:unprocessable_content)
        expect(violations.first).to include("date" => "2026-05-10", "kind" => "first_squad_cost")
        expect(response.parsed_body["error"]).to include("2026-05-10")
        expect(TeamMembershipChange.count).to eq(0)
        expect(target.reload.selected_cost_type).to eq("normal_cost")
      end

      it "5/10 の合計が 120 ちょうどになる契約変更は通る" do
        target = scenario
        CostPlayer.find_by!(player: target.player).update!(pitcher_only_cost: 8)

        post_players(payload(team.all_team_memberships.reload, overrides: { target.player_id => { selected_cost_type: "pitcher_only_cost" } }),
                     date: Date.new(2026, 5, 5))

        expect(response).to have_http_status(:ok)
        expect(target.reload.selected_cost_type).to eq("pitcher_only_cost")
      end

      it "放出で後の試合日(5/20)の 1軍が 24 人になるなら止める" do
        firsts = add_firsts(25)

        post_players(payload(firsts.drop(1)))

        expect(response).to have_http_status(:unprocessable_content)
        expect(violations.first).to include("kind" => "first_squad_min")
        expect(violations.map { |v| v["date"] }).to include("2026-05-20")
        expect(TeamMembershipChange.count).to eq(0)
        expect(SeasonRoster.where(team_membership: firsts.first).count).to eq(1)
        expect(firsts.first.reload.on_team).to be(true)
      end

      it "26 人からの放出で 25 人に留まるなら通る" do
        firsts = add_firsts(26)

        post_players(payload(firsts.drop(1)))

        expect(response).to have_http_status(:ok)
      end
    end

    describe "チーム全体のコスト(200)" do
      def twenty(count, cost_value)
        Array.new(count) { add_player(cost_value: cost_value) }
      end

      it "200 ちょうどは通り、201 は止める（書いた時点そのものの絶対の基準）" do
        members = twenty(20, 10) # 200
        extra = create(:player)
        create(:cost_player, cost: cost, player: extra, normal_cost: 1)
        post_players(payload(members))
        expect(response).to have_http_status(:ok)

        expect { post_players(payload(members) + [ new_player_param(extra) ]) }.not_to change(TeamMembershipChange, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["error"]).to include("201")
        expect(violations.first).to include("kind" => "team_total_cost", "date" => "2026-05-15")
        expect(TeamMembership.where(team: team, player: extra)).to be_empty
      end

      it "コスト除外(excluded_from_team_total)の選手は数えない" do
        members = twenty(20, 10)
        extra = create(:player)
        create(:cost_player, cost: cost, player: extra, normal_cost: 1)

        post_players(payload(members) + [ new_player_param(extra, excluded_from_team_total: true) ])

        expect(response).to have_http_status(:ok)
      end

      it "cost_list_id を省くと検査しない" do
        members = twenty(21, 10)
        post_players(payload(members), cost_list_id: nil)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "入力の検査" do
      it "不正な区分は 400（記録なし）" do
        member = add_player
        expect { post_players(payload([ member ], overrides: { member.player_id => { display_name: "x" } }), phase: "midnight") }
          .not_to change(TeamMembershipChange, :count)
        expect(response).to have_http_status(:bad_request)
      end

      it "不正な日付は 400（記録なし）" do
        member = add_player
        expect { post_players(payload([ member ]), date: "2026-13-45") }.not_to change(TeamMembershipChange, :count)
        expect(response).to have_http_status(:bad_request)
      end

      it "監督が同じ別チームの選手の登録は 422、取り消される" do
        manager = create(:manager)
        sibling_team = create(:team)
        create(:team_manager, team: team, manager: manager, role: :director)
        create(:team_manager, team: sibling_team, manager: manager, role: :director)
        player = create(:player)
        create(:team_membership, team: sibling_team, player: player)
        create(:cost_player, cost: cost, player: player, normal_cost: 5)

        expect { post_players([ new_player_param(player) ]) }.not_to change(TeamMembershipChange, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(TeamMembership.where(team: team, player: player)).to be_empty
      end

      it "別チームで放出済みの選手は、同じ監督のチームに登録できる" do
        manager = create(:manager)
        sibling_team = create(:team)
        create(:team_manager, team: team, manager: manager, role: :director)
        create(:team_manager, team: sibling_team, manager: manager, role: :director)
        player = create(:player)
        create(:team_membership, team: sibling_team, player: player).update_columns(on_team: false)
        create(:cost_player, cost: cost, player: player, normal_cost: 5)

        post_players([ new_player_param(player) ])

        expect(response).to have_http_status(:ok)
      end

      it "放出済みの選手の再登録も、同じ監督の別チームに在籍中なら 422（新規登録と同じ検証）。記録も在籍も戻さない" do
        manager = create(:manager)
        sibling_team = create(:team)
        create(:team_manager, team: team, manager: manager, role: :director)
        create(:team_manager, team: sibling_team, manager: manager, role: :director)
        keep = add_player
        leave = add_player
        post_players(payload([ keep ]))
        create(:team_membership, team: sibling_team, player: leave.player)

        expect { post_players(payload([ keep, leave ])) }.not_to change(TeamMembershipChange, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(leave.reload.on_team).to be(false)
      end

      it "players が無いと 400 相当のパラメータエラー" do
        post "/api/v1/teams/#{team.id}/team_players", params: { cost_list_id: cost.id }, as: :json
        expect(response).to have_http_status(:bad_request)
      end
    end

    describe "GET /teams/:team_id/team_players の時点指定" do
      it "target_date を省くと今の値、付けるとその時点の契約・在籍を返す" do
        member = add_player
        gone = add_player
        post_players(payload([ member ], overrides: { member.player_id => { selected_cost_type: "pitcher_only_cost", display_name: "転向" } }),
                     date: Date.new(2026, 5, 10))

        get "/api/v1/teams/#{team.id}/team_players"
        now = response.parsed_body
        expect(now.map { |p| p["id"] }).to eq([ member.player_id ])
        expect(now.first).to include("selected_cost_type" => "pitcher_only_cost", "display_name" => "転向")

        get "/api/v1/teams/#{team.id}/team_players", params: { target_date: "2026-05-09" }
        before_change = response.parsed_body
        expect(before_change.map { |p| p["id"] }).to contain_exactly(member.player_id, gone.player_id)
        expect(before_change.find { |p| p["id"] == member.player_id }).to include("selected_cost_type" => "normal_cost", "display_name" => nil)
      end

      it "不正な日付・区分は 400" do
        get "/api/v1/teams/#{team.id}/team_players", params: { target_date: "bad" }
        expect(response).to have_http_status(:bad_request)
        get "/api/v1/teams/#{team.id}/team_players", params: { target_date: "2026-05-09", phase: "x" }
        expect(response).to have_http_status(:bad_request)
      end
    end

    describe "GET /teams/:team_id/team_membership_changes" do
      let!(:member) { add_player }

      before do
        post_players(payload([ member ], overrides: { member.player_id => { display_name: "A" } }), date: Date.new(2026, 5, 10))
        post_players(payload([ member ], overrides: { member.player_id => { display_name: "B" } }), date: Date.new(2026, 5, 12), phase: "post_game")
        post_players(payload([ member ], overrides: { member.player_id => { display_name: "C" } }), date: Date.new(2026, 5, 12))
      end

      def listed(params = {})
        get "/api/v1/teams/#{team.id}/team_membership_changes", params: params
        response.parsed_body
      end

      it "時点順(日付・試合前→試合後・作成順)で全件を返す" do
        rows = listed
        expect(rows.map { |r| [ r["effective_on"], r["phase"], r["kind"], r["display_name"] ] }).to eq([
          [ "2026-04-01", "pre_game", "join", nil ],
          [ "2026-05-10", "pre_game", "contract", "A" ],
          [ "2026-05-12", "pre_game", "contract", "C" ],
          [ "2026-05-12", "post_game", "contract", "B" ]
        ])
        expect(rows.first).to include("team_membership_id" => member.id, "player_id" => member.player_id, "player_name" => member.player.name,
                                      "recorded_by_user_id" => user.id)
      end

      it "date はその日だけ、from / to は範囲で絞る" do
        expect(listed(date: "2026-05-12").map { |r| r["display_name"] }).to eq(%w[C B])
        expect(listed(from: "2026-05-10", to: "2026-05-10").map { |r| r["display_name"] }).to eq(%w[A])
        expect(listed(from: "2026-05-11").size).to eq(2)
        expect(listed(to: "2026-04-30").size).to eq(1)
      end

      it "不正な日付は 400" do
        get "/api/v1/teams/#{team.id}/team_membership_changes", params: { date: "bad" }
        expect(response).to have_http_status(:bad_request)
      end

      it "他チームの記録は含めない" do
        other = create(:team)
        other_season = create(:season, team: other)
        other_member = create(:team_membership, team: other)
        create(:team_membership_change, team_membership: other_member, season: other_season)

        expect(listed.map { |r| r["team_membership_id"] }.uniq).to eq([ member.id ])
      end
    end
  end

  context "他のユーザーのチーム" do
    include_context "authenticated user"

    it "書き込みも一覧も 403（チームへのアクセス権の検査はこれまでどおり）" do
      member = add_player
      post_players(payload([ member ], overrides: { member.player_id => { display_name: "x" } }))
      expect(response).to have_http_status(:forbidden)
      get "/api/v1/teams/#{team.id}/team_membership_changes"
      expect(response).to have_http_status(:forbidden)
      expect(TeamMembershipChange.count).to eq(0)
    end
  end

  context "コミッショナー" do
    include_context "authenticated commissioner"

    it "放出で後の試合日が 24 人になっても、警告(日付つき)つきで保存する" do
      firsts = add_firsts(25)

      post_players(payload(firsts.drop(1)))

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["warnings"].join).to include("2026-05-20")
      expect(firsts.first.reload.on_team).to be(false)
    end

    it "チーム全体 201 は、日付なしの文面で警告して保存する" do
      members = Array.new(20) { add_player(cost_value: 10) }
      extra = create(:player)
      create(:cost_player, cost: cost, player: extra, normal_cost: 1)

      post_players(payload(members) + [ new_player_param(extra) ])

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["warnings"].size).to eq(1)
      expect(response.parsed_body["warnings"].first).to include("201")
      expect(response.parsed_body["warnings"].first).not_to include("2026")
      expect(TeamMembership.where(team: team, player: extra).count).to eq(1)
    end

    it "放出済みの選手を、同じ監督の別チームに在籍中でも再登録できる" do
      manager = create(:manager)
      sibling_team = create(:team)
      create(:team_manager, team: team, manager: manager, role: :director)
      create(:team_manager, team: sibling_team, manager: manager, role: :director)
      keep = add_player
      leave = add_player
      post_players(payload([ keep ]))
      create(:team_membership, team: sibling_team, player: leave.player)

      post_players(payload([ keep, leave ]))

      expect(response).to have_http_status(:ok)
      expect(leave.reload.on_team).to be(true)
    end

    it "監督が同じ別チームの選手も登録できる" do
      manager = create(:manager)
      sibling_team = create(:team)
      create(:team_manager, team: team, manager: manager, role: :director)
      create(:team_manager, team: sibling_team, manager: manager, role: :director)
      player = create(:player)
      create(:team_membership, team: sibling_team, player: player)
      create(:cost_player, cost: cost, player: player, normal_cost: 5)

      post_players([ new_player_param(player) ])

      expect(response).to have_http_status(:ok)
      expect(TeamMembership.where(team: team, player: player).count).to eq(1)
    end
  end
end

# シーズンの無いチームは日付が無いので、これまでどおり行を直接書く（設計書 §4.2 の season_id が決まらない）
RSpec.describe "チーム編成の保存（シーズンの無いチーム）", type: :request do
  include_context "authenticated user"
  let(:team) { create(:team, user: user) }
  let(:cost) { create(:cost, end_date: nil) }

  it "行を直接書き、放出は行の削除。変更記録は作らない" do
    newcomer = create(:player)
    stay = create(:team_membership, team: team)
    gone = create(:team_membership, team: team)
    create(:cost_player, cost: cost, player: newcomer, normal_cost: 5)

    post "/api/v1/teams/#{team.id}/team_players",
         params: { players: [ { player_id: stay.player_id, selected_cost_type: "pitcher_only_cost", excluded_from_team_total: false },
                              { player_id: newcomer.id, selected_cost_type: "normal_cost", excluded_from_team_total: false } ] }, as: :json

    expect(response).to have_http_status(:ok)
    expect(TeamMembership.exists?(gone.id)).to be(false)
    expect(stay.reload.selected_cost_type).to eq("pitcher_only_cost")
    expect(team.team_memberships.count).to eq(2)
    expect(TeamMembershipChange.count).to eq(0)
  end
end
