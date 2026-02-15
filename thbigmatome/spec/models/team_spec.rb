require "rails_helper"

RSpec.describe Team, type: :model do
  let(:team) { create(:team) }
  let(:cost) { create(:cost) }

  # ヘルパー: プレイヤーをチームに登録し、コストを設定する
  def add_player_to_team(team:, cost:, player_trait: nil, squad: "second", cost_value: 5, cost_type: "normal_cost", excluded: false)
    player = player_trait ? create(:player, player_trait) : create(:player)
    membership = create(:team_membership,
      team: team,
      player: player,
      squad: squad,
      selected_cost_type: cost_type,
      excluded_from_team_total: excluded
    )
    create(:cost_player, cost: cost, player: player, normal_cost: cost_value)
    { player: player, membership: membership }
  end

  # ヘルパー: 外の世界タイプを選手に付与
  def assign_outside_world_type(player)
    ow_type = PlayerType.find_or_create_by!(name: "外の世界", category: "outside_world")
    PlayerPlayerType.create!(player: player, player_type: ow_type)
  end

  # ヘルパー: 東方タイプを選手に付与
  def assign_touhou_type(player)
    touhou_type = PlayerType.find_or_create_by!(name: "東方", category: "touhou")
    PlayerPlayerType.create!(player: player, player_type: touhou_type)
  end

  # ヘルパー: 二刀流タイプを選手に付与
  def assign_two_way_type(player)
    two_way_type = PlayerType.find_or_create_by!(name: "二刀流")
    PlayerPlayerType.create!(player: player, player_type: two_way_type)
  end

  # ============================================================
  # コスト上限バリデーション
  # ============================================================

  describe "#validate_team_total_cost" do
    context "チーム全体コスト" do
      it "合計コスト200以下なら有効" do
        # 40人 x 5コスト = 200
        40.times { add_player_to_team(team: team, cost: cost, cost_value: 5) }

        expect(team.validate_team_total_cost(cost.id)).to be true
        expect(team.errors[:base]).to be_empty
      end

      it "合計コスト200ちょうどなら有効（境界値）" do
        # 20人 x 10コスト = 200
        20.times { add_player_to_team(team: team, cost: cost, cost_value: 10) }

        expect(team.validate_team_total_cost(cost.id)).to be true
        expect(team.errors[:base]).to be_empty
      end

      it "合計コスト201以上ならエラー" do
        # 20人 x 10コスト = 200, + 1人 x 1コスト = 201
        20.times { add_player_to_team(team: team, cost: cost, cost_value: 10) }
        add_player_to_team(team: team, cost: cost, cost_value: 1)

        expect(team.validate_team_total_cost(cost.id)).to be false
        expect(team.errors[:base]).to include(
          I18n.t("activerecord.errors.models.team.cost_limit.cost_exceeds_limit", cost: 201, limit: 200)
        )
      end

      it "excluded_from_team_total=trueの選手はチーム全体コストに含まれない" do
        # 通常選手: 20人 x 10コスト = 200
        20.times { add_player_to_team(team: team, cost: cost, cost_value: 10) }
        # 除外選手: 5人 x 10コスト（これが含まれると250で超過するが、除外されるので200）
        5.times { add_player_to_team(team: team, cost: cost, cost_value: 10, excluded: true) }

        expect(team.validate_team_total_cost(cost.id)).to be true
        expect(team.errors[:base]).to be_empty
      end

      it "excluded_from_team_total=falseの選手のみでコスト計算される" do
        # 通常選手: 21人 x 10コスト = 210（超過）
        21.times { add_player_to_team(team: team, cost: cost, cost_value: 10) }

        expect(team.validate_team_total_cost(cost.id)).to be false
        expect(team.errors[:base]).not_to be_empty
      end

      it "コスト未設定の選手は0として計算される" do
        # コスト設定なしの選手を直接作成
        player = create(:player)
        create(:team_membership, team: team, player: player)
        # cost_playerを作成しない

        expect(team.validate_team_total_cost(cost.id)).to be true
        expect(team.errors[:base]).to be_empty
      end
    end
  end

  # ============================================================
  # 1軍人数別コスト上限（クラスメソッド）
  # ============================================================

  describe ".first_squad_cost_limit_for_count" do
    context "1軍人数別コスト上限" do
      it "28人以上で上限120を返す" do
        expect(Team.first_squad_cost_limit_for_count(28)).to eq(120)
      end

      it "30人でも上限120を返す" do
        expect(Team.first_squad_cost_limit_for_count(30)).to eq(120)
      end

      it "27人で上限119を返す" do
        expect(Team.first_squad_cost_limit_for_count(27)).to eq(119)
      end

      it "26人で上限117を返す" do
        expect(Team.first_squad_cost_limit_for_count(26)).to eq(117)
      end

      it "25人で上限114を返す" do
        expect(Team.first_squad_cost_limit_for_count(25)).to eq(114)
      end

      it "24人以下はnilを返す（登録禁止）" do
        expect(Team.first_squad_cost_limit_for_count(24)).to be_nil
      end

      it "0人でもnilを返す" do
        expect(Team.first_squad_cost_limit_for_count(0)).to be_nil
      end
    end
  end

  describe ".first_squad_minimum_players" do
    it "最低人数25を返す" do
      expect(Team.first_squad_minimum_players).to eq(25)
    end
  end

  # config/cost_limits.yml との連動確認
  describe "COST_LIMIT_CONFIG" do
    it "config/cost_limits.ymlの設定値と一致する" do
      config = YAML.load_file(Rails.root.join("config", "cost_limits.yml"))

      expect(Team::TEAM_TOTAL_MAX_COST).to eq(config["team_total_max_cost"])
      expect(Team::TEAM_TOTAL_MAX_COST).to eq(200)

      tiers = config["first_squad_tiers"]
      expect(tiers.size).to eq(4)
      expect(tiers[0]).to eq({ "min_players" => 28, "max_cost" => 120 })
      expect(tiers[1]).to eq({ "min_players" => 27, "max_cost" => 119 })
      expect(tiers[2]).to eq({ "min_players" => 26, "max_cost" => 117 })
      expect(tiers[3]).to eq({ "min_players" => 25, "max_cost" => 114 })

      expect(config["first_squad_minimum_players"]).to eq(25)
    end
  end

  # ============================================================
  # 外の世界枠バリデーション
  # ============================================================

  describe "#validate_outside_world_limit" do
    context "人数制限" do
      it "外の世界選手が0人なら有効" do
        expect(team.validate_outside_world_limit).to be true
        expect(team.errors[:base]).to be_empty
      end

      it "外の世界選手が4人以下なら有効" do
        4.times do
          result = add_player_to_team(team: team, cost: cost, squad: "first")
          assign_outside_world_type(result[:player])
        end

        expect(team.validate_outside_world_limit).to be true
        expect(team.errors[:base]).to be_empty
      end

      it "外の世界選手が4人ちょうどなら有効（境界値）" do
        4.times do
          result = add_player_to_team(team: team, cost: cost, squad: "first")
          assign_outside_world_type(result[:player])
        end

        expect(team.validate_outside_world_limit).to be true
      end

      it "外の世界選手が5人以上ならエラー" do
        5.times do
          result = add_player_to_team(team: team, cost: cost, squad: "first")
          assign_outside_world_type(result[:player])
        end

        expect(team.validate_outside_world_limit).to be false
        expect(team.errors[:base]).to include(
          I18n.t("activerecord.errors.models.team.outside_world.limit_exceeded", count: 5, limit: 4)
        )
      end

      it "2軍の外の世界選手はカウントしない" do
        # 1軍に4人
        4.times do
          result = add_player_to_team(team: team, cost: cost, squad: "first")
          assign_outside_world_type(result[:player])
        end
        # 2軍に3人（これがカウントされると7人で超過するが、1軍のみなので4人）
        3.times do
          result = add_player_to_team(team: team, cost: cost, squad: "second")
          assign_outside_world_type(result[:player])
        end

        expect(team.validate_outside_world_limit).to be true
      end

      it "東方選手はカウントしない" do
        # 1軍に外の世界4人
        4.times do
          result = add_player_to_team(team: team, cost: cost, squad: "first")
          assign_outside_world_type(result[:player])
        end
        # 1軍に東方5人（東方はカウント対象外）
        5.times do
          result = add_player_to_team(team: team, cost: cost, squad: "first")
          assign_touhou_type(result[:player])
        end

        expect(team.validate_outside_world_limit).to be true
      end

      it "カテゴリなしのタイプを持つ選手はカウントしない" do
        # 1軍に外の世界4人
        4.times do
          result = add_player_to_team(team: team, cost: cost, squad: "first")
          assign_outside_world_type(result[:player])
        end
        # カテゴリなしのタイプのみの選手
        result = add_player_to_team(team: team, cost: cost, squad: "first")
        generic_type = PlayerType.find_or_create_by!(name: "テスト用タイプ")
        PlayerPlayerType.create!(player: result[:player], player_type: generic_type)

        expect(team.validate_outside_world_limit).to be true
      end
    end
  end

  describe "#validate_outside_world_balance" do
    context "投手/野手混在制約（4人時のみ）" do
      it "4人で投手と野手が混在していれば有効" do
        # 投手2人 + 野手2人
        2.times do
          result = add_player_to_team(team: team, cost: cost, squad: "first", player_trait: :pitcher)
          assign_outside_world_type(result[:player])
        end
        2.times do
          result = add_player_to_team(team: team, cost: cost, squad: "first", player_trait: :fielder)
          assign_outside_world_type(result[:player])
        end

        expect(team.validate_outside_world_balance).to be true
        expect(team.errors[:base]).to be_empty
      end

      it "4人で投手1人+野手3人でも有効" do
        result = add_player_to_team(team: team, cost: cost, squad: "first", player_trait: :pitcher)
        assign_outside_world_type(result[:player])
        3.times do
          result = add_player_to_team(team: team, cost: cost, squad: "first", player_trait: :fielder)
          assign_outside_world_type(result[:player])
        end

        expect(team.validate_outside_world_balance).to be true
      end

      it "4人で全員投手ならエラー" do
        4.times do
          result = add_player_to_team(team: team, cost: cost, squad: "first", player_trait: :pitcher)
          assign_outside_world_type(result[:player])
        end

        expect(team.validate_outside_world_balance).to be false
        expect(team.errors[:base]).to include(
          I18n.t("activerecord.errors.models.team.outside_world.balance_required")
        )
      end

      it "4人で全員野手ならエラー" do
        4.times do
          result = add_player_to_team(team: team, cost: cost, squad: "first", player_trait: :fielder)
          assign_outside_world_type(result[:player])
        end

        expect(team.validate_outside_world_balance).to be false
        expect(team.errors[:base]).to include(
          I18n.t("activerecord.errors.models.team.outside_world.balance_required")
        )
      end

      it "二刀流選手は投手としても野手としてもカウント可能（全員二刀流で有効）" do
        4.times do
          result = add_player_to_team(team: team, cost: cost, squad: "first", player_trait: :two_way)
          assign_outside_world_type(result[:player])
          assign_two_way_type(result[:player])
        end

        expect(team.validate_outside_world_balance).to be true
      end

      it "二刀流1人+野手3人なら有効（二刀流が投手枠を埋める）" do
        # 二刀流1人
        result = add_player_to_team(team: team, cost: cost, squad: "first", player_trait: :two_way)
        assign_outside_world_type(result[:player])
        assign_two_way_type(result[:player])
        # 野手3人
        3.times do
          result = add_player_to_team(team: team, cost: cost, squad: "first", player_trait: :fielder)
          assign_outside_world_type(result[:player])
        end

        expect(team.validate_outside_world_balance).to be true
      end

      it "二刀流1人+投手3人なら有効（二刀流が野手枠を埋める）" do
        # 二刀流1人
        result = add_player_to_team(team: team, cost: cost, squad: "first", player_trait: :two_way)
        assign_outside_world_type(result[:player])
        assign_two_way_type(result[:player])
        # 投手3人
        3.times do
          result = add_player_to_team(team: team, cost: cost, squad: "first", player_trait: :pitcher)
          assign_outside_world_type(result[:player])
        end

        expect(team.validate_outside_world_balance).to be true
      end

      it "3人以下なら混在制約はかからない（全員投手でも有効）" do
        3.times do
          result = add_player_to_team(team: team, cost: cost, squad: "first", player_trait: :pitcher)
          assign_outside_world_type(result[:player])
        end

        expect(team.validate_outside_world_balance).to be true
      end

      it "3人以下なら混在制約はかからない（全員野手でも有効）" do
        3.times do
          result = add_player_to_team(team: team, cost: cost, squad: "first", player_trait: :fielder)
          assign_outside_world_type(result[:player])
        end

        expect(team.validate_outside_world_balance).to be true
      end

      it "0人なら有効" do
        expect(team.validate_outside_world_balance).to be true
      end
    end
  end

  # ============================================================
  # outside_world_first_squad_memberships
  # ============================================================

  describe "#outside_world_first_squad_memberships" do
    it "1軍の外の世界選手のメンバーシップのみを返す" do
      # 1軍外の世界選手
      ow_result = add_player_to_team(team: team, cost: cost, squad: "first")
      assign_outside_world_type(ow_result[:player])

      # 1軍東方選手
      touhou_result = add_player_to_team(team: team, cost: cost, squad: "first")
      assign_touhou_type(touhou_result[:player])

      # 2軍外の世界選手
      second_ow_result = add_player_to_team(team: team, cost: cost, squad: "second")
      assign_outside_world_type(second_ow_result[:player])

      # タイプなし1軍選手
      add_player_to_team(team: team, cost: cost, squad: "first")

      result = team.outside_world_first_squad_memberships
      expect(result.size).to eq(1)
      expect(result.first.player).to eq(ow_result[:player])
    end
  end
end
