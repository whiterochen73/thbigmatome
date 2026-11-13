require "rails_helper"

# 登録の 422 の本文（cmd_1894/subtask_1894a）。
# 既定ロケール（en）のまま I18n.with_locale で包まずに叩き、文言が Translation missing にならず日本語で返ることを確かめる。
# Test Basis: queue/reports/reviewer_subtask_1893e.yaml 指摘 1（文言は ja.yml にだけあり、実環境では Translation missing になる）。
RSpec.describe "登録の 422 の本文（既定ロケール）", type: :request do
  include_context "authenticated user"

  let(:team) { create(:team, user: user) }
  let(:cost) { create(:cost, end_date: nil) }

  def post_players(players)
    post "/api/v1/teams/#{team.id}/team_players", params: { players: players, cost_list_id: cost.id }, as: :json
  end

  def param_for(player, card: nil)
    { player_id: player.id, selected_cost_type: "normal_cost", excluded_from_team_total: false, display_name: nil, player_card_id: card&.id }
  end

  def new_player(name = nil)
    pl = create(:player, **{ name: name }.compact)
    create(:cost_player, cost: cost, player: pl, normal_cost: 3)
    pl
  end

  def error_text = response.parsed_body["error"].to_s

  it "テストはロケールを包んでいない（既定は en）" do
    expect(I18n.locale).to eq(:en)
  end

  it "現行外のカード" do
    pl = new_player
    old = create(:player_card, player: pl, card_set: create(:card_set, name: "旧セット", is_current: false))
    post_players([ param_for(pl, card: old) ])
    expect(response).to have_http_status(:unprocessable_content)
    expect(error_text).to eq("旧セットは現行のカードセットではないため、このカードは選べません")
    expect(error_text).not_to match(/translation missing/i)
  end

  it "公式戦使用不可のカード" do
    pl = new_player
    banned = create(:player_card, player: pl, card_set: create(:card_set), official_use_prohibited: true)
    post_players([ param_for(pl, card: banned) ])
    expect(response).to have_http_status(:unprocessable_content)
    expect(error_text).to eq("公式戦で使用できないカードは選べません")
  end

  it "同キャラの 2 枚目" do
    a = new_player("冴月 麟 (投手)")
    b = new_player("冴月 麟 (野手)")
    post_players([ param_for(a), param_for(b) ])
    expect(response).to have_http_status(:unprocessable_content)
    expect(error_text).to eq("冴月 麟 (野手)は同じキャラクターの冴月 麟 (投手)が既に所属しています")
    expect(error_text).not_to match(/translation missing/i)
  end

  it "同じ監督の別チームに在籍中の選手（既存の player_in_sibling_team）" do
    manager = create(:manager)
    sibling = create(:team, name: "別チーム")
    create(:team_manager, team: team, manager: manager, role: :director)
    create(:team_manager, team: sibling, manager: manager, role: :director)
    pl = new_player("射命丸 文")
    create(:team_membership, team: sibling, player: pl)
    post_players([ param_for(pl) ])
    expect(response).to have_http_status(:unprocessable_content)
    expect(error_text).to eq("射命丸 文は既に別チームに所属しています")
    expect(error_text).not_to match(/translation missing/i)
  end

  it "既存の ja 専用文言（マスタの変更不可）も en で引ける" do
    expect(I18n.t("master_data.managed_by_config_file")).to eq("このマスタデータは設定ファイルで管理されています")
  end

  it "en の既定のバリデーション文は英語のまま（fallback で ja に化けない）" do
    expect(I18n.t("errors.messages.blank")).to eq("can't be blank")
  end
end
