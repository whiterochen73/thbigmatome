require "rails_helper"
require "csv"

# Test Basis: cmd_1898 subtask_1898b §1（PM2026 在籍 → PM2027 の付け替え）。
# 当て先は同じ Player・同じ種別・同じ variant の現行 PM 系カード 1 枚。既定は dry-run（書かない）。実行は writer 経由で変更記録を足し、戻しは足した記録を消す。
RSpec.describe PmCardSwap do
  let!(:pm2026) { create(:card_set, name: "PM2026", set_type: "pm2026", is_current: false) }
  let!(:pm2027) { create(:card_set, name: "PM2027", set_type: "pm2027", is_current: true) }
  let(:team) { create(:team) }
  let!(:season) { create(:season, team: team, current_date: Date.new(2026, 5, 15)) }
  let!(:cost) { create(:cost, start_date: Date.new(2020, 1, 1), end_date: nil) }

  # 在籍中の PM2026 は、PM2026 が現行だった頃に登録されたもの。作る間だけ現行に戻す（カード変更時の検査が現行外を拒むため）
  def membership_with(card, team: self.team, **attrs)
    was = card.card_set.is_current
    card.card_set.update_column(:is_current, true)
    create(:team_membership, team: team, player: card.player, player_card: card, **attrs)
  ensure
    card.card_set.update_column(:is_current, was)
  end

  def old_and_new(variant: nil, card_type: "batter", player: create(:player))
    old = create(:player_card, player: player, card_set: pm2026, card_type: card_type, variant: variant)
    new = create(:player_card, player: player, card_set: pm2027, card_type: card_type, variant: variant)
    [ old, new ]
  end

  describe "#plan（読むだけ）" do
    it "同じ Player・種別・variant の現行 PM カードがあれば付け替え対象にする（コスト・中身の差の印つき）" do
      old, new = old_and_new(variant: "湘南")
      tm = membership_with(old)

      row = described_class.new.plan.sole

      expect(row.status).to eq("swap")
      expect([ row.membership_id, row.from_card_id, row.to_card_id ]).to eq([ tm.id, old.id, new.id ])
      expect(row.cost_changed).to be(false)
      expect(row.content_changed).to be(false)
    end

    it "カードの中身（打撃表以外の数値）が違えば content_changed の印を付ける" do
      old, new = old_and_new
      new.update!(steal_start: old.steal_start + 1)
      membership_with(old)

      expect(described_class.new.plan.sole.content_changed).to be(true)
    end

    it "種別違い（PM2027 は投手だけ）は当てず、理由を出す" do
      player = create(:player)
      old = create(:player_card, player: player, card_set: pm2026, card_type: "batter")
      create(:player_card, player: player, card_set: pm2027, card_type: "pitcher")
      membership_with(old)

      row = described_class.new.plan.sole
      expect(row.status).to eq("skip")
      expect(row.reason).to start_with("no_target")
    end

    it "variant 違い（空と UR）は当てない" do
      player = create(:player)
      old = create(:player_card, player: player, card_set: pm2026, variant: "UR")
      create(:player_card, player: player, card_set: pm2027, variant: nil)
      membership_with(old)

      expect(described_class.new.plan.sole.status).to eq("skip")
    end

    it "現行の PM2027 のカードが無ければ当てない" do
      old = create(:player_card, card_set: pm2026)
      membership_with(old)

      expect(described_class.new.plan.sole.reason).to start_with("no_target")
    end

    it "同キャラの別 Player にだけ当て先がある時は、手がかりを理由に書いて付け替えない" do
      base = create(:player, name: "西行寺 幽々子")
      twin = create(:player, name: "西行寺 幽々子(楼閣)")
      old = create(:player_card, player: base, card_set: pm2026, variant: "楼閣")
      create(:player_card, player: twin, card_set: pm2027)
      membership_with(old)

      row = described_class.new.plan.sole
      expect(row.status).to eq("skip")
      expect(row.reason).to include("same character, other player")
    end

    it "公式戦使用不可の PM2027 カードには替えない" do
      old, new = old_and_new
      new.update!(official_use_prohibited: true)
      membership_with(old)

      expect(described_class.new.plan.sole.reason).to eq("target_official_use_prohibited")
    end

    it "退団済み（on_team = false）・現行セットのカード・カード無しの所属は対象にしない" do
      old, = old_and_new
      membership_with(old, on_team: false)
      current_card = create(:player_card, card_set: pm2027)
      membership_with(current_card)
      create(:team_membership, team: team, player_card: nil)

      expect(described_class.new.plan).to be_empty
    end

    it "TEAM_IDS・MEMBERSHIP_IDS で絞れる" do
      other_team = create(:team)
      create(:season, team: other_team)
      old1, = old_and_new
      old2, = old_and_new
      old3, = old_and_new
      tm1 = membership_with(old1)
      membership_with(old2, team: other_team)
      tm3 = membership_with(old3)

      expect(described_class.new(team_ids: [ team.id ]).plan.map(&:membership_id)).to contain_exactly(tm1.id, tm3.id)
      expect(described_class.new(membership_ids: [ tm3.id ]).plan.map(&:membership_id)).to eq([ tm3.id ])
    end

    it "コストが変わる付け替えは cost_changed の印を付ける" do
      old, new = old_and_new
      membership_with(old)
      create(:cost_player, cost: cost, player: old.player, player_card: old, normal_cost: 4)
      create(:cost_player, cost: cost, player: new.player, player_card: new, normal_cost: 6)

      row = described_class.new.plan.sole
      expect([ row.cost_before, row.cost_after, row.cost_changed ]).to eq([ 4, 6, true ])
    end
  end

  describe "#apply!" do
    it "dry-run は DB を書かない（変更記録も増えない）" do
      old, = old_and_new
      tm = membership_with(old)

      rows = nil
      expect { rows = described_class.new.apply!(dry_run: true) }.not_to change { [ TeamMembershipChange.count, tm.reload.player_card_id ] }
      expect(rows.sole.status).to eq("dry_run_ok")
    end

    it "実行すると現在日付で contract の変更記録を足し、所属のカードが替わる。契約・除外・表示名は今のまま" do
      old, new = old_and_new
      tm = membership_with(old, selected_cost_type: "fielder_only_cost", display_name: "表示", excluded_from_team_total: true)

      row = described_class.new.apply!(dry_run: false).sole

      expect(row.status).to eq("applied")
      expect(tm.reload.player_card_id).to eq(new.id)
      expect([ tm.selected_cost_type, tm.display_name, tm.excluded_from_team_total ]).to eq([ "fielder_only_cost", "表示", true ])
      contract = TeamMembershipChange.where(team_membership: tm, kind: "contract").sole
      expect([ contract.effective_on, contract.phase, contract.player_card_id ]).to eq([ Date.new(2026, 5, 15), "pre_game", new.id ])
      expect(row.change_ids).to include(contract.id)
    end

    it "対象でない所属は放出されず、値も変わらない（writer は送られなかった在籍者を放出するため）" do
      old, new = old_and_new
      membership_with(old)
      bystander = create(:team_membership, team: team, selected_cost_type: "normal_cost", squad: "second")
      other_old, = old_and_new
      other_tm = membership_with(other_old)

      described_class.new(membership_ids: [ other_tm.id ]).apply!(dry_run: false)

      expect(bystander.reload.on_team).to be(true)
      expect(TeamMembershipChange.where(team_membership: bystander, kind: "release")).to be_empty
      expect(TeamMembership.find_by(player_card_id: old.id)).to be_present # 絞りの外の所属は PM2026 のまま
      expect(TeamMembership.find_by(player_card_id: new.id)).to be_nil
    end

    it "同じチームの複数の所属を替えられる" do
      old1, new1 = old_and_new
      old2, new2 = old_and_new
      membership_with(old1)
      membership_with(old2)

      rows = described_class.new.apply!(dry_run: false)

      expect(rows.map(&:status)).to eq(%w[applied applied])
      expect(TeamMembership.where(team: team).pluck(:player_card_id)).to contain_exactly(new1.id, new2.id)
    end

    it "検査で止まった所属は理由つきで飛ばし、ほかの所属は続ける" do
      old1, = old_and_new
      old2, new2 = old_and_new
      tm1 = membership_with(old1)
      tm2 = membership_with(old2)
      # tm1 の当て先だけ、書く直前に現行外へ（card_registration_error が止める）
      allow(TeamMembership).to receive(:card_registration_error).and_wrap_original do |m, card|
        card&.id == PlayerCard.find_by(player_id: tm1.player_id, card_set_id: pm2027.id).id ? "登録できないカード" : m.call(card)
      end

      rows = described_class.new.apply!(dry_run: false)

      expect(rows.map { |r| [ r.membership_id, r.status ] }).to eq([ [ tm1.id, "invalid" ], [ tm2.id, "applied" ] ])
      expect(rows.first.reason).to include("登録できないカード")
      expect(tm1.reload.player_card_id).to eq(old1.id)
      expect(tm2.reload.player_card_id).to eq(new2.id)
    end

    it "現在日より後の日付の変更記録を持つ所属は、写しが上書きされるので替えず理由を出す" do
      old, = old_and_new
      tm = membership_with(old)
      create(:team_membership_change, team_membership: tm, season: season, kind: "join", effective_on: Date.new(2026, 1, 1),
                                      selected_cost_type: "normal_cost", player_card: old)
      create(:team_membership_change, team_membership: tm, season: season, kind: "contract", effective_on: Date.new(2026, 7, 1),
                                      selected_cost_type: "normal_cost", player_card: old)

      row = described_class.new.apply!(dry_run: false).sole

      expect(row.status).to eq("not_applied")
      expect(row.reason).to eq("later_dated_change_records_exist")
      expect(tm.reload.player_card_id).to eq(old.id)
      expect(TeamMembershipChange.where(team_membership: tm).count).to eq(2)
    end

    it "シーズンの無いチームは行のカードを直接書き換える（変更記録は足さない）" do
      no_season_team = create(:team)
      old, new = old_and_new
      tm = membership_with(old, team: no_season_team)

      row = described_class.new(team_ids: [ no_season_team.id ]).apply!(dry_run: false).sole

      expect(row.status).to eq("applied")
      expect(tm.reload.player_card_id).to eq(new.id)
      expect(TeamMembershipChange.where(team_membership: tm)).to be_empty
    end
  end

  describe ".revert!" do
    def swap_and_csv(**filter)
      rows = described_class.new(**filter).apply!(dry_run: false)
      io = StringIO.new
      described_class.revert_csv(rows, io)
      CSV.parse(io.string, headers: true).map(&:to_h)
    end

    it "戻し用 CSV で元のカードに戻り、足した変更記録も消える" do
      old, new = old_and_new
      tm = membership_with(old)
      before_changes = TeamMembershipChange.count
      entries = swap_and_csv
      expect(tm.reload.player_card_id).to eq(new.id)
      expect(entries.sole["from_card_id"]).to eq(old.id.to_s)

      results = described_class.revert!(entries, dry_run: false)

      expect(results.sole[:status]).to eq("restored")
      expect(tm.reload.player_card_id).to eq(old.id)
      expect(TeamMembershipChange.count).to be >= before_changes
      expect(TeamMembershipChange.where(team_membership: tm, kind: "contract")).to be_empty
    end

    it "dry-run の戻しは書かない" do
      old, new = old_and_new
      tm = membership_with(old)
      entries = swap_and_csv

      described_class.revert!(entries, dry_run: true)

      expect(tm.reload.player_card_id).to eq(new.id)
    end

    it "付け替えの後でカードや記録が動いた所属は戻さず理由を出す" do
      old, new = old_and_new
      tm = membership_with(old)
      entries = swap_and_csv
      other = create(:player_card, player: old.player, card_set: pm2027, variant: "別")
      tm.update_columns(player_card_id: other.id)

      expect(described_class.revert!(entries, dry_run: false).sole[:status]).to eq("skip")

      tm.update_columns(player_card_id: new.id)
      later = TeamMembershipChange.create!(team_membership: tm, season: season, kind: "contract", effective_on: Date.new(2026, 6, 1),
                                           phase: "pre_game", selected_cost_type: "normal_cost", player_card_id: new.id)
      result = described_class.revert!(entries, dry_run: false).sole
      expect(result[:reason]).to eq("later_changes_exist")
      expect(later.reload).to be_present
      expect(tm.reload.player_card_id).to eq(new.id)
    end

    it "シーズンの無いチームの所属も戻せる" do
      no_season_team = create(:team)
      old, new = old_and_new
      tm = membership_with(old, team: no_season_team)
      entries = swap_and_csv(team_ids: [ no_season_team.id ])
      expect(tm.reload.player_card_id).to eq(new.id)

      described_class.revert!(entries, dry_run: false)

      expect(tm.reload.player_card_id).to eq(old.id)
    end
  end
end
