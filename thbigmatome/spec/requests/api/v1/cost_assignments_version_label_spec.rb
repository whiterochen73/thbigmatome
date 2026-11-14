require "rails_helper"

# コスト登録の行（カード別）が、variant の無い完走カード（帯のチーム名 team_label だけ）でも、カード別のコスト行があれば出る（cmd_1902）。
# 行が出ないと、その値を画面から直せず、版の印も出ない。
RSpec.describe "コスト登録のカード別の行", type: :request do
  include_context "authenticated user"

  let!(:cost) { create(:cost) }
  let!(:other_cost) { create(:cost, start_date: Date.new(2020, 1, 1), end_date: Date.new(2020, 12, 31)) }
  let!(:player) { create(:player) }

  def rows
    get "/api/v1/cost_assignments", params: { cost_id: cost.id }
    response.parsed_body.select { |r| r["id"] == player.id }
  end

  it "variant なし・team_label ありで、この改定にカード別の行があるカードは行が出て、version_label が付く" do
    card = create(:player_card, player: player, variant: nil, team_label: "永山")
    create(:cost_player, cost: cost, player: player, player_card: card, normal_cost: 8)

    row = rows.find { |r| r["player_card_id"] == card.id }
    expect(row).to include("version_label" => "永山", "normal_cost" => 8)
  end

  it "別の改定にしかカード別の行が無いカード（variant なし）は出ない・variant ありのカードは従来どおり出る" do
    plain = create(:player_card, player: player, variant: nil, team_label: "永山")
    tagged = create(:player_card, player: player, variant: "飯能", card_type: "pitcher")
    create(:cost_player, cost: other_cost, player: player, player_card: plain, normal_cost: 8)

    ids = rows.map { |r| r["player_card_id"] }
    expect(ids).to contain_exactly(nil, tagged.id)
    expect(rows.find { |r| r["player_card_id"] == tagged.id }["version_label"]).to eq("飯能")
  end

  it "カードが 1 枚だけで印も行も無い選手は、既定の 1 行だけ" do
    create(:player_card, player: player, variant: nil, team_label: nil)
    expect(rows.map { |r| r["player_card_id"] }).to eq([ nil ])
  end
end
