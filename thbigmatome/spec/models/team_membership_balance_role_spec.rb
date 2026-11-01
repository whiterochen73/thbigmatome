require "rails_helper"

# Test Basis: context/thbig-bench-rule-adjudications.md AMB-29 の改訂（2026-11-02、Operator 決定・暫定）
#   1. 専任契約が最優先（投手専任・救援専任＝投手のみ、野手専任＝野手のみ）
#   2. 二刀流（両方に数える）は二刀流契約（two_way_cost）のときだけ（Operator 決定「コストと揃えて二刀流でいい。二刀流になるのは二刀流契約したときだけ」）
#   3. それ以外は選んだカードの主な位置で、投手（P）＝投手、それ以外＝野手（card_type・can_pitch?・P 守備の有無では決めない）
# 取込 CSV（db/import/player_cards.csv）の実カード: 魔理沙 card_seq 3（position 投手・守備 P/OF）、天弓千亦 card_seq 20（内野手・card_type pitcher・救援専任）、
# 涼宮ハルヒ card_seq 240（hachinai6.1・内野手・card_type pitcher）。cmd_1808。
RSpec.describe TeamMembership, "外の世界枠のバランスでの投手・野手の数え方", type: :model do
  let(:team) { create(:team, team_type: "normal") }
  let(:annual_set) { create(:card_set, set_type: "annual") }
  let(:hachinai_set) { create(:card_set, set_type: "hachinai61", year: 2061) }

  def membership_for(player, card, cost_type)
    build(:team_membership, team: team, player: player, player_card: card, squad: "first", selected_cost_type: cost_type)
  end

  def kind_of(membership)
    membership.pitcher_fielder_kind
  end

  describe "実カードの例" do
    context "魔理沙（2025THBIG card_seq 3。主な位置は投手、守備は P/OF）" do
      let(:player) { create(:player, name: "霧雨 魔理沙", series: "touhou", number: "1") }
      let(:card) do
        create(:player_card, player: player, card_set: annual_set, card_type: "pitcher", is_pitcher: true).tap do |c|
          %w[P OF].each { |pos| c.player_card_defenses.create!(position: pos, range_value: 3, error_rank: "C") }
        end
      end

      it "通常契約は投手のみ" do
        expect(kind_of(membership_for(player, card, "normal_cost"))).to eq(:pitcher_only)
      end

      it "野手専任契約は野手のみ（専任契約が最優先）" do
        expect(kind_of(membership_for(player, card, "fielder_only_cost"))).to eq(:fielder_only)
      end

      it "投手専任・救援専任契約は投手のみ" do
        expect(kind_of(membership_for(player, card, "pitcher_only_cost"))).to eq(:pitcher_only)
        expect(kind_of(membership_for(player, card, "relief_only_cost"))).to eq(:pitcher_only)
      end

      it "二刀流契約（two_way_cost）なら両方に数える" do
        expect(kind_of(membership_for(player, card, "two_way_cost"))).to eq(:two_way)
      end
    end

    context "天弓千亦（2025THBIG card_seq 20。card_type は pitcher・救援専任カードだが、主な位置は内野手）" do
      let(:player) { create(:player, name: "天弓 千亦", series: "touhou", number: "129") }
      let(:card) do
        create(:player_card, player: player, card_set: annual_set, card_type: "pitcher", is_pitcher: true, is_relief_only: true).tap do |c|
          %w[3B SS OF C 2B 1B P].each { |pos| c.player_card_defenses.create!(position: pos, range_value: 3, error_rank: "C") }
        end
      end

      it "通常契約は野手のみ（P 守備があっても card_type が pitcher でも、主な位置で決める）" do
        membership = membership_for(player, card, "normal_cost")

        expect(membership.pitcher_role?).to be false
        expect(membership.fielder_role?).to be true
        expect(kind_of(membership)).to eq(:fielder_only)
      end

      it "救援専任契約なら投手のみ（専任契約が最優先）" do
        expect(kind_of(membership_for(player, card, "relief_only_cost"))).to eq(:pitcher_only)
      end

      it "画面の表示・先発/救援の判定（is_pitcher など）は従来のまま、投手として使うカードのまま" do
        membership = membership_for(player, card, "normal_cost")

        expect(membership.pitching_role?).to be true
        expect(membership.relief_only_role?).to be true
        expect(membership.roster_position).to eq("pitcher")
      end
    end

    context "涼宮ハルヒ（hachinai6.1 card_seq 240。card_type は pitcher、主な位置は内野手）" do
      let(:player) { create(:player, name: "涼宮 ハルヒ", series: "hachinai", number: "46") }
      let(:card) do
        create(:player_card, player: player, card_set: hachinai_set, card_type: "pitcher", is_pitcher: true).tap do |c|
          %w[2B P SS CF].each { |pos| c.player_card_defenses.create!(position: pos, range_value: 3, error_rank: "C") }
        end
      end

      it "hachinai_two_way? は偽（背番号 46、カードは 1 枚）で、通常契約は野手のみ" do
        membership = membership_for(player, card, "normal_cost")

        expect(player.hachinai_two_way?).to be false
        expect(kind_of(membership)).to eq(:fielder_only)
      end

      it "背番号が 39 以下で hachinai_two_way? が真でも、二刀流契約でなければ主な位置で決める（通常契約＝野手のみ）" do
        card # カードを作ってから番号を変える
        player.update!(number: "30")

        expect(player.reload.hachinai_two_way?).to be true
        expect(kind_of(membership_for(player, card, "normal_cost"))).to eq(:fielder_only)
      end

      it "背番号が 39 以下（片方のカードだけの二刀流）の子が二刀流契約すれば、両方に数える" do
        card
        player.update!(number: "30")

        expect(kind_of(membership_for(player.reload, card, "two_way_cost"))).to eq(:two_way)
      end
    end
  end

  describe "二刀流契約・専任契約（選んだコスト区分で決める）" do
    it "ハチナイ二刀流の選手: 二刀流契約は両方、投手専任・救援専任は投手のみ、野手専任は野手のみ（available_cost_types の 4 通り）" do
      expected = {
        "two_way_cost" => :two_way,
        "pitcher_only_cost" => :pitcher_only, "relief_only_cost" => :pitcher_only, "fielder_only_cost" => :fielder_only
      }

      actual = expected.keys.to_h { |cost| [ cost, kind_of(add_outside_world_member(team, :two_way, cost_type: cost)) ] }

      expect(actual).to eq(expected)
    end

    it "ハチナイ二刀流の選手でも、通常契約（実際は選べない）なら主な位置で決める" do
      expect(kind_of(add_outside_world_member(team, :two_way, cost_type: "normal_cost"))).to eq(:fielder_only)
    end

    it "ハチナイ以外で投手カードと野手カードの両方を持つ選手も、二刀流契約すれば両方に数える" do
      player = create(:player, series: "tamayomi", number: "60")
      set = create(:card_set, set_type: "tamayomi2")
      pitcher_card = add_card(player, set, "pitcher", %w[P])
      fielder_card = add_card(player, set, "batter", %w[SS])

      expect(player.hachinai_two_way?).to be false
      expect(kind_of(membership_for(player, pitcher_card, "two_way_cost"))).to eq(:two_way)
      expect(kind_of(membership_for(player, fielder_card, "two_way_cost"))).to eq(:two_way)
    end

    it "同じ選手は、投手専任なら投手のみ、野手専任なら野手のみ、二刀流契約なら両方" do
      player = create(:player, series: "tamayomi", number: "60")
      set = create(:card_set, set_type: "tamayomi2")
      card = add_card(player, set, "pitcher", %w[P])
      add_card(player, create(:card_set, set_type: "hachinai61", year: 2061), "batter", %w[SS])

      kinds = %w[pitcher_only_cost fielder_only_cost two_way_cost].to_h { |cost| [ cost, kind_of(membership_for(player, card, cost)) ] }

      expect(kinds).to eq("pitcher_only_cost" => :pitcher_only, "fielder_only_cost" => :fielder_only, "two_way_cost" => :two_way)
    end

    it "救援専任の二刀流は、野手カードを選んでいても投手のみ（pitcher_role? 真・fielder_role? 偽）" do
      membership = add_outside_world_member(team, :two_way, cost_type: "relief_only_cost")

      expect(membership.pitcher_role?).to be true
      expect(membership.fielder_role?).to be false
    end
  end

  describe "二刀流契約・専任契約以外は、選んだカードの主な位置で決める" do
    it "主な位置が投手（P）のカードは、card_type が batter でも投手のみ" do
      expect(kind_of(add_outside_world_member(team, :batter_card_pitcher))).to eq(:pitcher_only)
    end

    it "主な位置が野手のカードは、card_type が pitcher でも野手のみ" do
      expect(kind_of(add_outside_world_member(team, :pitcher_card_infielder))).to eq(:fielder_only)
    end

    it "通常の投手カード・野手カード" do
      expect(kind_of(add_outside_world_member(team, :pitcher))).to eq(:pitcher_only)
      expect(kind_of(add_outside_world_member(team, :fielder))).to eq(:fielder_only)
    end

    it "守備が 1 つも無いカードは、P が無いので野手" do
      player = create(:player, series: "tamayomi", number: "50")
      card = create(:player_card, player: player, card_set: create(:card_set, set_type: "tamayomi2"), card_type: "batter")

      expect(kind_of(membership_for(player, card, "normal_cost"))).to eq(:fielder_only)
    end

    it "主な位置は守備の id 順の 1 つ目（読み込み順に左右されない）" do
      membership = add_outside_world_member(team, :pitcher_card_infielder)
      card = PlayerCard.preload(:player_card_defenses).find(membership.player_card_id)

      expect(card.primary_position).to eq("3B")
    end

    it "カードを登録していない選手は決められないので、どちらにも数えない（二刀流・専任契約は契約と選手で決まる）" do
      expect(kind_of(add_outside_world_member(team, :no_card))).to be_nil
      expect(kind_of(add_outside_world_member(team, :no_card, cost_type: "pitcher_only_cost"))).to eq(:pitcher_only)
    end
  end
end
