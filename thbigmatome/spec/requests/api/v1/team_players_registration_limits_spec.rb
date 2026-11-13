require "rails_helper"

# 登録画面の API（POST /teams/:id/team_players）の登録の制限（cmd_1893/subtask_1893e）。
# 経路は 3 つ: シーズンありの新規登録（join）・放出済みの再登録（rejoin）・カードの変更（contract）と、シーズンなしのチームの直接書き込み。
# Test Basis: Operator 裁定（2026-11-14）。現行外・公式戦使用不可のカードは選べない／既存の所属は消さず書き換えない／同キャラは同じチームに 2 枚入れられない
# （数字の添え字は別人）。コミッショナーにも同じ規則を適用する（裁定に例外が無い）。
RSpec.describe "チーム編成の保存の登録の制限", type: :request do
  around { |example| I18n.with_locale(:ja) { example.run } }

  let(:cost) { create(:cost, end_date: nil) }
  let(:current_set) { create(:card_set) }
  let(:old_set) { create(:card_set, is_current: false) }

  def post_players(team, players, date: nil)
    params = { players: players, cost_list_id: cost.id }
    params[:target_date] = date.to_s if date
    post "/api/v1/teams/#{team.id}/team_players", params: params, as: :json
  end

  def param_for(player, card: nil, **extra)
    { player_id: player.id, selected_cost_type: "normal_cost", excluded_from_team_total: false, display_name: nil, player_card_id: card&.id }.merge(extra)
  end

  def new_player(name = nil, **attrs)
    pl = create(:player, **{ name: name }.compact, **attrs)
    create(:cost_player, cost: cost, player: pl, normal_cost: 3)
    pl
  end

  def error_text = response.parsed_body["error"].to_s

  shared_examples "登録の制限" do
    it "現行外のカードで新規登録すると 422 で、所属は作られない" do
      pl = new_player
      expect { post_players(team, [ param_for(pl, card: create(:player_card, player: pl, card_set: old_set)) ]) }
        .not_to change(TeamMembership, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(error_text).to be_present
    end

    it "公式戦使用不可のカードで新規登録すると 422" do
      pl = new_player
      banned = create(:player_card, player: pl, card_set: current_set, official_use_prohibited: true)
      post_players(team, [ param_for(pl, card: banned) ])
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "現行カードで新規登録は 200" do
      pl = new_player
      post_players(team, [ param_for(pl, card: create(:player_card, player: pl, card_set: current_set)) ])
      expect(response).to have_http_status(:ok)
      expect(team.all_team_memberships.find_by!(player: pl).player_card).to be_present
    end

    it "冴月 麟 (投手) の居るチームへ 冴月 麟 (野手) を足すと 422（同キャラ）" do
      a = new_player("冴月 麟 (投手)")
      b = new_player("冴月 麟 (野手)")
      post_players(team, [ param_for(a) ])
      expect(response).to have_http_status(:ok)
      post_players(team, [ param_for(a), param_for(b) ])
      expect(response).to have_http_status(:unprocessable_content)
      expect(team.all_team_memberships.where(player: b)).to be_empty
    end

    it "同じ保存で 冴月 麟 (投手) を外して 冴月 麟 (野手) を入れるのは通る（入れ替え）" do
      a = new_player("冴月 麟 (投手)")
      b = new_player("冴月 麟 (野手)")
      post_players(team, [ param_for(a) ])
      post_players(team, [ param_for(b) ])
      expect(response).to have_http_status(:ok)
      expect(team.all_team_memberships.where(player: b, on_team: true)).to exist
    end

    it "同じ保存で同キャラを 2 人新しく入れると 422" do
      a = new_player("八雲 紫")
      b = new_player("八雲 紫 (エイプリル)")
      post_players(team, [ param_for(a), param_for(b) ])
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "Aal と Aal (2) は同じチームに入れられる" do
      a = new_player("Aal")
      b = new_player("Aal (2)")
      post_players(team, [ param_for(a), param_for(b) ])
      expect(response).to have_http_status(:ok)
      expect(team.all_team_memberships.count).to eq(2)
    end

    it "既に同キャラが 2 人入っているチームの保存（表示名の変更など）は、同キャラを新しく足さない限り通る" do
      a = new_player("冴月 麟 (投手)")
      b = new_player("冴月 麟 (野手)")
      [ a, b ].each do |pl|
        tm = TeamMembership.new(team: team, player: pl, squad: "second", selected_cost_type: "normal_cost")
        tm.save!(validate: false)
      end
      post_players(team, [ param_for(a, display_name: "投"), param_for(b) ])
      expect(response).to have_http_status(:ok)
      expect(team.all_team_memberships.count).to eq(2)
    end

    it "現行外のカードを持つ既存の所属は、同じカードのまま送り直しても（ほかの値を変えても）消えず・書き換わらず 200" do
      pl = new_player
      old_card = create(:player_card, player: pl, card_set: old_set)
      tm = TeamMembership.new(team: team, player: pl, squad: "second", selected_cost_type: "normal_cost")
      tm.save!(validate: false)
      tm.update_columns(player_card_id: old_card.id)

      post_players(team, [ param_for(pl, card: old_card, display_name: "名") ])
      expect(response).to have_http_status(:ok)
      expect(tm.reload.player_card_id).to eq(old_card.id)
      expect(tm.display_name).to eq("名")
    end

    it "既存の所属のカードを現行外のカードへ替えると 422、現行カードへ替えると 200" do
      pl = new_player
      cur = create(:player_card, player: pl, card_set: current_set)
      old_card = create(:player_card, player: pl, card_set: old_set, card_type: "pitcher")
      post_players(team, [ param_for(pl, card: cur) ])
      expect(response).to have_http_status(:ok)

      post_players(team, [ param_for(pl, card: old_card) ])
      expect(response).to have_http_status(:unprocessable_content)
      expect(team.all_team_memberships.find_by!(player: pl).player_card_id).to eq(cur.id)

      other = create(:player_card, player: pl, card_set: current_set, card_type: "pitcher")
      post_players(team, [ param_for(pl, card: other) ])
      expect(response).to have_http_status(:ok)
      expect(team.all_team_memberships.find_by!(player: pl).player_card_id).to eq(other.id)
    end
  end

  context "シーズンありのチーム（変更記録の経路）・一般ユーザー" do
    include_context "authenticated user"
    let(:team) { create(:team, user: user) }
    before do
      season = create(:season, team: team)
      create(:season_schedule, season: season, date: "2026-04-01", date_type: "game_day")
      pin_current_date(season, Date.new(2026, 5, 15))
    end
    include_examples "登録の制限"

    it "放出済みの選手を現行外のカードで再登録すると 422（再登録も新しい登録）" do
      pl = new_player
      old_card = create(:player_card, player: pl, card_set: old_set)
      stay = new_player
      post_players(team, [ param_for(pl), param_for(stay) ])
      post_players(team, [ param_for(stay) ])
      expect(team.all_team_memberships.find_by!(player: pl).on_team).to be(false)
      before = TeamMembershipChange.count

      post_players(team, [ param_for(stay), param_for(pl, card: old_card) ])
      expect(response).to have_http_status(:unprocessable_content)
      expect(TeamMembershipChange.count).to eq(before)
    end

    it "放出済みの選手を現行カードで再登録すると 200" do
      pl = new_player
      stay = new_player
      post_players(team, [ param_for(pl), param_for(stay) ])
      post_players(team, [ param_for(stay) ])
      expect(team.all_team_memberships.find_by!(player: pl).on_team).to be(false)
      post_players(team, [ param_for(stay), param_for(pl, card: create(:player_card, player: pl, card_set: current_set)) ])
      expect(response).to have_http_status(:ok)
      expect(team.all_team_memberships.find_by!(player: pl).on_team).to be(true)
    end
  end

  context "シーズンありのチーム・コミッショナー" do
    include_context "authenticated commissioner"
    let(:team) { create(:team) }
    before do
      season = create(:season, team: team)
      create(:season_schedule, season: season, date: "2026-04-01", date_type: "game_day")
      pin_current_date(season, Date.new(2026, 5, 15))
    end
    include_examples "登録の制限"
  end

  context "シーズンなしのチーム（行を直接書く経路）・一般ユーザー" do
    include_context "authenticated user"
    let(:team) { create(:team, user: user) }
    include_examples "登録の制限"
  end

  context "シーズンなしのチーム・コミッショナー" do
    include_context "authenticated commissioner"
    let(:team) { create(:team) }
    include_examples "登録の制限"
  end
end
