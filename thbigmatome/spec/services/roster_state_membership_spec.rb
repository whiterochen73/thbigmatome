require "rails_helper"

# Test Basis: context/thbig-dugout-season-record-restructure-design.md §4.1（時点 = 日付 + 区分）・§4.2（team_membership_changes は変更後の値を丸ごと持つ）・
# §4.3（RosterState.at の on_team・契約・カードは、その時点以前で最新の team_membership_changes）・§5.2 段2（記録が無い行は今の値）
RSpec.describe RosterState, "チーム編成の変更記録（cmd_1784 段2）" do
  let(:team) { create(:team) }
  let(:season) { create(:season, team: team, current_date: Date.new(2026, 5, 15)) }
  let!(:membership) { create(:team_membership, team: team, selected_cost_type: "normal_cost") }
  let(:card_a) { create(:player_card, player: membership.player) }
  let(:card_b) { create(:player_card, player: membership.player) }

  def change(kind, on, phase: "pre_game", cost: "normal_cost", card: nil, excluded: false, display_name: nil, tm: membership)
    create(:team_membership_change, team_membership: tm, season: season, kind: kind, effective_on: on, phase: phase,
                                    selected_cost_type: cost, player_card: card, excluded_from_team_total: excluded, display_name: display_name)
  end

  def entry_at(date, phase = "pre_game", tm: membership)
    described_class.at(team, Date.parse(date), phase).fetch(tm.id)
  end

  describe "記録が無い行" do
    it "行の今の値を全時点の値として読む（在籍中）" do
      membership.update!(selected_cost_type: "pitcher_only_cost", excluded_from_team_total: true, display_name: "ミ")

      entry = entry_at("2026-01-01")
      expect(entry).to have_attributes(on_team: true, selected_cost_type: "pitcher_only_cost", excluded_from_team_total: true, display_name: "ミ")
    end

    it "放出済みの写し(on_team=false)で記録が無い行は、在籍なしと読む" do
      membership.update_columns(on_team: false)
      expect(entry_at("2026-05-01").on_team).to be(false)
    end
  end

  describe "join / contract / release の境界" do
    before do
      change("join", Date.new(2026, 4, 1), cost: "normal_cost", card: card_a)
      change("contract", Date.new(2026, 5, 10), cost: "relief_only_cost", card: card_b, excluded: true, display_name: "新")
      change("release", Date.new(2026, 6, 1), cost: "relief_only_cost", card: card_b)
    end

    it "最初の記録(join)より前の時点は、まだチームにいない" do
      expect(entry_at("2026-03-31", "post_game").on_team).to be(false)
      expect(entry_at("2026-04-01").on_team).to be(true)
    end

    it "契約の変更は、その日の試合前から効き、前日の試合後にはまだ効かない" do
      before_change = entry_at("2026-05-09", "post_game")
      expect(before_change).to have_attributes(selected_cost_type: "normal_cost", player_card_id: card_a.id,
                                               excluded_from_team_total: false, display_name: nil)
      after_change = entry_at("2026-05-10", "pre_game")
      expect(after_change).to have_attributes(selected_cost_type: "relief_only_cost", player_card_id: card_b.id,
                                              excluded_from_team_total: true, display_name: "新")
    end

    it "放出の日の試合前までは在籍中、放出の記録の時点から在籍なし" do
      expect(entry_at("2026-05-31", "post_game").on_team).to be(true)
      expect(entry_at("2026-06-01", "pre_game").on_team).to be(false)
      expect(entry_at("2026-12-01").on_team).to be(false)
    end

    it "試合後(post_game)の契約変更は、同じ日の試合前・試合中にはまだ効かない" do
      change("contract", Date.new(2026, 5, 20), phase: "post_game", cost: "fielder_only_cost", card: card_b)
      expect(entry_at("2026-05-20", "pre_game").selected_cost_type).to eq("relief_only_cost")
      expect(entry_at("2026-05-20", "in_game").selected_cost_type).to eq("relief_only_cost")
      expect(entry_at("2026-05-20", "post_game").selected_cost_type).to eq("fielder_only_cost")
    end

    it "同じ時点の記録は作成順で、後に作った方が勝つ" do
      change("contract", Date.new(2026, 5, 10), cost: "two_way_cost", card: card_a)
      expect(entry_at("2026-05-10").selected_cost_type).to eq("two_way_cost")
    end

    it "再登録(join)で在籍に戻る" do
      change("join", Date.new(2026, 7, 1), cost: "normal_cost", card: card_a)
      expect(entry_at("2026-06-15").on_team).to be(false)
      expect(entry_at("2026-07-01")).to have_attributes(on_team: true, selected_cost_type: "normal_cost")
    end
  end

  describe "1軍の判定" do
    it "放出済みの選手は、昇降格の記録が first のままでも 1軍に数えない" do
      create(:season_roster, season: season, team_membership: membership, squad: "first", registered_on: Date.new(2026, 4, 1))
      change("join", Date.new(2026, 4, 1))
      change("release", Date.new(2026, 6, 1))

      expect(described_class.new(team).first_memberships(Date.new(2026, 5, 31)).map(&:id)).to eq([ membership.id ])
      expect(described_class.new(team).first_memberships(Date.new(2026, 6, 1))).to be_empty
      expect(entry_at("2026-06-01")).to have_attributes(squad: "second", on_team: false)
    end

    it "まだ登録されていない時点では 1軍に数えない" do
      create(:season_roster, season: season, team_membership: membership, squad: "first", registered_on: Date.new(2026, 4, 1))
      change("join", Date.new(2026, 5, 1))

      expect(described_class.new(team).first_memberships(Date.new(2026, 4, 15))).to be_empty
    end
  end

  describe "#view（時点の契約を反映した TeamMembership）" do
    it "値が行と同じなら行そのもの、違えば時点の契約とカードを持つ未保存の写しを返す" do
      change("join", Date.new(2026, 4, 1), cost: "normal_cost", card: card_a)
      change("contract", Date.new(2026, 5, 10), cost: "fielder_only_cost", card: card_b)
      membership.update_columns(selected_cost_type: "fielder_only_cost", player_card_id: card_b.id)
      state = described_class.new(team)

      latest = state.view(state.memberships.first, state.at(Date.new(2026, 5, 10)).fetch(membership.id))
      expect(latest.equal?(state.memberships.first)).to be(true)

      past = state.view(state.memberships.first, state.at(Date.new(2026, 4, 1)).fetch(membership.id))
      expect(past).to have_attributes(id: membership.id, selected_cost_type: "normal_cost", player_card_id: card_a.id)
      expect(past).to be_readonly
      expect(past.new_record?).to be(true)
    end
  end

  describe "#record_points" do
    it "昇降格の記録の時点と、チーム編成の記録の時点の両方を昇順で返す" do
      create(:season_roster, season: season, team_membership: membership, squad: "first", registered_on: Date.new(2026, 5, 5))
      change("join", Date.new(2026, 4, 1))
      change("release", Date.new(2026, 5, 5), phase: "post_game")

      expect(described_class.new(team).record_points)
        .to eq([ [ Date.new(2026, 4, 1), "pre_game" ], [ Date.new(2026, 5, 5), "pre_game" ], [ Date.new(2026, 5, 5), "post_game" ] ])
    end
  end

  describe "#rebuild_membership_cache!" do
    it "最後の記録の値で行の写し(在籍・契約・カード・コスト除外・表示名)を作り直し、変わった列を返す" do
      change("join", Date.new(2026, 4, 1), cost: "normal_cost")
      change("contract", Date.new(2026, 5, 10), cost: "pitcher_only_cost", card: card_a, excluded: true, display_name: "新")
      change("release", Date.new(2026, 6, 1), cost: "pitcher_only_cost", card: card_a, excluded: true, display_name: "新")

      changed = described_class.new(team).rebuild_membership_cache!

      expect(changed.map { |tm, diff| [ tm.id, diff.keys.sort ] })
        .to eq([ [ membership.id, %i[display_name excluded_from_team_total on_team player_card_id selected_cost_type] ] ])
      expect(membership.reload).to have_attributes(on_team: false, selected_cost_type: "pitcher_only_cost", player_card_id: card_a.id,
                                                   excluded_from_team_total: true, display_name: "新")
    end

    it "記録の無い行は触らない" do
      membership.update_columns(selected_cost_type: "two_way_cost")
      expect(described_class.new(team).rebuild_membership_cache!).to eq([])
      expect(membership.reload.selected_cost_type).to eq("two_way_cost")
    end

    it "すでに一致していれば何も書かない" do
      change("join", Date.new(2026, 4, 1), cost: "normal_cost")
      expect(described_class.new(team).rebuild_membership_cache!).to eq([])
    end
  end

  describe "#on_team_memberships / #first_memberships（在籍の読み。subtask_1784i の生存変異 M08）" do
    let(:state) { described_class.new(team) }
    let!(:off_team_no_record) { create(:team_membership, team: team).tap { |tm| tm.update_columns(on_team: false) } }

    it "記録が無い行は、行の今の値の在籍(on_team)で読む。在籍外(false)の行は出さない" do
      ids = state.on_team_memberships(Date.new(2026, 5, 1)).map(&:id)

      expect(ids).to eq([ membership.id ])
      expect(ids).not_to include(off_team_no_record.id)
    end

    it "記録のある行は、最初の記録より前の日付では在籍外（記録が無い行の倒し先とは別）" do
      change("join", Date.new(2026, 4, 1))

      expect(described_class.new(team).on_team_memberships(Date.new(2026, 3, 31), "post_game").map(&:id)).to be_empty
      expect(described_class.new(team).on_team_memberships(Date.new(2026, 4, 1)).map(&:id)).to eq([ membership.id ])
    end

    it "在籍外の行が 1軍の最後の記録を持っていても、1軍には数えない" do
      create(:season_roster, season: season, team_membership: off_team_no_record, squad: "first", registered_on: Date.new(2026, 4, 1))

      expect(described_class.new(team).first_memberships(Date.new(2026, 5, 1)).map(&:id)).to be_empty
    end
  end

  describe "#view（契約・カード・除外が同じで表示名だけ違う時点。subtask_1784i の生存変異 M21）" do
    it "行の今の値ではなく、その時点の表示名の view を返す" do
      change("join", Date.new(2026, 4, 1), display_name: "旧")
      change("contract", Date.new(2026, 5, 10), display_name: "新")
      membership.update_columns(display_name: "新")
      state = described_class.new(team)

      past = state.view(membership.reload, state.entry(membership.id, Date.new(2026, 5, 1)))
      now = state.view(membership, state.entry(membership.id, Date.new(2026, 5, 10)))

      expect(past.display_name).to eq("旧")
      expect(past).to be_readonly
      expect(now).to equal(membership)
    end
  end

  describe "Team の関連" do
    it "team_memberships は在籍中だけ、all_team_memberships は放出済みも含む" do
      released = create(:team_membership, team: team)
      released.update_columns(on_team: false)

      expect(team.reload.team_memberships.map(&:id)).to eq([ membership.id ])
      expect(team.all_team_memberships.map(&:id)).to contain_exactly(membership.id, released.id)
      expect(team.players.map(&:id)).to eq([ membership.player_id ])
    end
  end
end
