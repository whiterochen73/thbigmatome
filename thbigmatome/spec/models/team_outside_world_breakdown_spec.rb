require "rails_helper"

# Test Basis: context/thbig-bench-rule-adjudications.md AMB-29（外の世界枠 4 人のときの投手・野手の内訳。
# 改訂（2026-11-02）: 専任契約が最優先、二刀流契約（two_way_cost）のときだけ両方、それ以外は選んだカードの主な位置で投手/野手）、
# ルールブック 02「バランスルール」（外の世界選手が 4 人のとき投手 1 名以上・野手 1 名以上）、cmd_1808。
RSpec.describe Team, "外の世界枠の投手・野手の内訳", type: :model do
  let(:team) { create(:team, team_type: "normal") }
  def add_outside(kind, cost_type: nil)
    add_outside_world_member(team, kind, cost_type: cost_type)
  end

  def breakdown
    team.reload
    Team.outside_world_breakdown(team.outside_world_first_squad_memberships)
  end

  describe "#validate_outside_world_balance" do
    it "4 人で全員投手なら違反" do
      4.times { add_outside(:pitcher) }

      expect(team.reload.validate_outside_world_balance).to be false
      expect(team.errors[:base]).to include(I18n.t("activerecord.errors.models.team.outside_world.balance_required"))
    end

    it "4 人で全員野手なら違反" do
      4.times { add_outside(:fielder) }

      expect(team.reload.validate_outside_world_balance).to be false
    end

    it "4 人で投手と野手が混在していれば有効" do
      2.times { add_outside(:pitcher) }
      2.times { add_outside(:fielder) }

      expect(team.reload.validate_outside_world_balance).to be true
    end

    it "全員投手でも、二刀流 1 人で補えば有効（二刀流は野手にも数える）" do
      3.times { add_outside(:pitcher) }
      add_outside(:two_way)

      expect(team.reload.validate_outside_world_balance).to be true
    end

    it "全員野手でも、二刀流 1 人で補えば有効（二刀流は投手にも数える）" do
      3.times { add_outside(:fielder) }
      add_outside(:two_way)

      expect(team.reload.validate_outside_world_balance).to be true
    end

    it "投手専任契約の二刀流は投手のみ: 投手 3 人 + 投手専任の二刀流は違反" do
      3.times { add_outside(:pitcher) }
      add_outside(:two_way, cost_type: "pitcher_only_cost")

      expect(team.reload.validate_outside_world_balance).to be false
    end

    it "救援専任契約の二刀流は投手のみ: 投手 3 人 + 救援専任の二刀流（野手カード）は違反" do
      3.times { add_outside(:pitcher) }
      add_outside(:two_way, cost_type: "relief_only_cost")

      expect(team.reload.validate_outside_world_balance).to be false
    end

    it "救援専任契約の二刀流は投手に数える: 野手 3 人 + 救援専任の二刀流（野手カード）は有効" do
      3.times { add_outside(:fielder) }
      add_outside(:two_way, cost_type: "relief_only_cost")

      expect(team.reload.validate_outside_world_balance).to be true
    end

    it "野手専任契約の二刀流は野手のみ: 野手 3 人 + 野手専任の二刀流は違反" do
      3.times { add_outside(:fielder) }
      add_outside(:two_way, cost_type: "fielder_only_cost")

      expect(team.reload.validate_outside_world_balance).to be false
    end

    it "野手専任契約の二刀流は野手に数える: 投手 3 人 + 野手専任の二刀流は有効" do
      3.times { add_outside(:pitcher) }
      add_outside(:two_way, cost_type: "fielder_only_cost")

      expect(team.reload.validate_outside_world_balance).to be true
    end

    it "card_type が pitcher でも主な位置が内野手のカードは野手: 4 人全員なら違反" do
      4.times { add_outside(:pitcher_card_infielder) }

      expect(team.reload.validate_outside_world_balance).to be false
    end

    it "card_type が batter でも主な位置が投手のカードは投手: 野手 3 人 + そのカードで有効" do
      3.times { add_outside(:fielder) }
      add_outside(:batter_card_pitcher)

      expect(team.reload.validate_outside_world_balance).to be true
    end

    it "カードを登録していない選手はどちらにも数えない: 投手 3 人 + カード無し 1 人は違反" do
      3.times { add_outside(:pitcher) }
      add_outside(:no_card)

      expect(team.reload.validate_outside_world_balance).to be false
    end

    it "3 人以下なら内訳を問わない（全員投手でも有効）" do
      3.times { add_outside(:pitcher) }

      expect(team.reload.validate_outside_world_balance).to be true
    end

    it "5 人で全員投手なら違反（4 人以上は内訳を見る）" do
      5.times { add_outside(:pitcher) }

      expect(team.reload.validate_outside_world_balance).to be false
    end

    it "5 人で投手と野手が混在していれば内訳は有効（人数の超過は別の規定）" do
      3.times { add_outside(:pitcher) }
      2.times { add_outside(:fielder) }

      expect(team.reload.validate_outside_world_balance).to be true
    end
  end

  describe ".outside_world_breakdown" do
    it "投・野・二刀流の人数と balance_ok を返す（二刀流は別枠）" do
      2.times { add_outside(:pitcher) }
      add_outside(:fielder)
      add_outside(:two_way)

      expect(breakdown).to eq(pitcher_only: 2, fielder_only: 1, two_way: 1, balance_ok: true)
    end

    it "専任契約の二刀流は専任の方に入る（投手専任・救援専任は投、野手専任は野）" do
      add_outside(:two_way, cost_type: "pitcher_only_cost")
      add_outside(:two_way, cost_type: "relief_only_cost")
      add_outside(:two_way, cost_type: "fielder_only_cost")
      add_outside(:two_way, cost_type: "two_way_cost")

      expect(breakdown).to eq(pitcher_only: 2, fielder_only: 1, two_way: 1, balance_ok: true)
    end

    it "4 人で全員投手なら balance_ok が false" do
      4.times { add_outside(:pitcher) }

      expect(breakdown).to eq(pitcher_only: 4, fielder_only: 0, two_way: 0, balance_ok: false)
    end

    it "3 人以下は全員投手でも balance_ok が true" do
      3.times { add_outside(:pitcher) }

      expect(breakdown).to eq(pitcher_only: 3, fielder_only: 0, two_way: 0, balance_ok: true)
    end

    it "外の世界が 0 人なら全部 0・balance_ok は true" do
      expect(Team.outside_world_breakdown([])).to eq(pitcher_only: 0, fielder_only: 0, two_way: 0, balance_ok: true)
    end

    it "検査（validate_outside_world_balance）と balance_ok は同じ結果になる" do
      3.times { add_outside(:pitcher) }
      add_outside(:two_way, cost_type: "relief_only_cost")

      expect(breakdown[:balance_ok]).to be false
      expect(team.reload.validate_outside_world_balance).to be false
    end
  end
end
