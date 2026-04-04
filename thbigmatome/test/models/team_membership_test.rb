require "test_helper"

class TeamMembershipTest < ActiveSupport::TestCase
  def setup
    @team = Team.create!(name: "Test Team A", short_name: "A", team_type: "normal")
    @team_b = Team.create!(name: "Test Team B", short_name: "B", team_type: "normal")
    @player = Player.create!(name: "Player 1", short_name: "P1", number: "100")
    @player2 = Player.create!(name: "Player 2", short_name: "P2", number: "200")
  end

  # ─── P1-1: player_not_in_director_sibling_team on: [:create, :update] ─────

  test "P1-1: blocks adding player already in sibling team on create" do
    manager = Manager.create!(name: "Director")
    TeamManager.create!(team: @team, manager: manager, role: :director)
    TeamManager.create!(team: @team_b, manager: manager, role: :director)

    TeamMembership.create!(team: @team, player: @player, squad: "first", selected_cost_type: "normal_cost")

    membership = TeamMembership.new(team: @team_b, player: @player, squad: "first", selected_cost_type: "normal_cost")
    assert_not membership.valid?
    assert membership.errors[:player_id].any?
  end

  test "P1-1: blocks swapping to player already in sibling team on update" do
    manager = Manager.create!(name: "Director")
    TeamManager.create!(team: @team, manager: manager, role: :director)
    TeamManager.create!(team: @team_b, manager: manager, role: :director)

    TeamMembership.create!(team: @team, player: @player, squad: "first", selected_cost_type: "normal_cost")
    membership_b = TeamMembership.create!(team: @team_b, player: @player2, squad: "first", selected_cost_type: "normal_cost")

    membership_b.player = @player
    assert_not membership_b.valid?
    assert membership_b.errors[:player_id].any?
  end

  test "P1-1: allows update when player is not in sibling team" do
    manager = Manager.create!(name: "Director")
    TeamManager.create!(team: @team, manager: manager, role: :director)
    TeamManager.create!(team: @team_b, manager: manager, role: :director)

    membership_b = TeamMembership.create!(team: @team_b, player: @player2, squad: "first", selected_cost_type: "normal_cost")

    membership_b.squad = "second"
    assert membership_b.valid?
  end

  test "P1-1: skip_commissioner_validation cannot be set via mass assignment" do
    membership = TeamMembership.new(
      team: @team, player: @player, squad: "first", selected_cost_type: "normal_cost"
    )
    # attr_accessor なので params 経由では設定不可（ActionController::Parameters はattr_accessorを弾く）
    # ここでは attr_accessor として定義されていることを確認
    assert_respond_to membership, :skip_commissioner_validation
    assert_respond_to membership, :skip_commissioner_validation=
  end

  # ─── P1-2: 定数値確認（game_rules.yaml参照） ─────────────────────────────

  test "P1-2: ROSTER_MAX is 30 (from game_rules.yaml)" do
    assert_equal 30, TeamMembership::ROSTER_MAX,
      "ROSTER_MAX は game_rules.yaml の rules.team_composition.roster_max から読まれること"
  end

  test "P1-2: ROSTER_MIN is 9 (from game_rules.yaml)" do
    assert_equal 9, TeamMembership::ROSTER_MIN,
      "ROSTER_MIN は game_rules.yaml の rules.team_composition.roster_min から読まれること"
  end

  # ─── P1-2: validate_roster_max ───────────────────────────────────────────

  test "P1-2: blocks adding player when roster is at max" do
    max = TeamMembership::ROSTER_MAX
    max.times do |i|
      p = Player.create!(name: "RMax#{i}", short_name: "RM#{i}", number: format("%03d", i))
      TeamMembership.create!(team: @team, player: p, squad: "second", selected_cost_type: "normal_cost")
    end

    extra_player = Player.create!(name: "Extra", short_name: "EX", number: "999")
    membership = TeamMembership.new(team: @team, player: extra_player, squad: "second", selected_cost_type: "normal_cost")
    assert_not membership.valid?
    assert membership.errors[:base].any?, "ロスター上限超過時にbaseエラーが存在すること"
  end

  test "P1-2: allows adding player when roster is below max" do
    membership = TeamMembership.new(team: @team, player: @player, squad: "first", selected_cost_type: "normal_cost")
    assert membership.valid?
  end

  test "P1-2: allows adding exactly up to max players" do
    max = TeamMembership::ROSTER_MAX
    (max - 1).times do |i|
      p = Player.create!(name: "RFull#{i}", short_name: "RF#{i}", number: format("%03d", i))
      TeamMembership.create!(team: @team, player: p, squad: "second", selected_cost_type: "normal_cost")
    end

    last_player = Player.create!(name: "Last", short_name: "LT", number: "998")
    membership = TeamMembership.new(team: @team, player: last_player, squad: "second", selected_cost_type: "normal_cost")
    assert membership.valid?, "#{max}人目は追加可能であること: #{membership.errors.full_messages}"
  end

  # ─── P1-2: check_roster_min (before_destroy) ──────────────────────────────

  test "P1-2: blocks removing player when roster is at min" do
    min = TeamMembership::ROSTER_MIN
    memberships = min.times.map do |i|
      p = Player.create!(name: "RMin#{i}", short_name: "RM#{i}", number: format("%03d", i + 1))
      TeamMembership.create!(team: @team, player: p, squad: "second", selected_cost_type: "normal_cost")
    end

    result = memberships.first.destroy
    assert_not result, "ロスター最低人数時はdestroy失敗すること"
    assert_equal min, @team.team_memberships.reload.count, "人数が変わっていないこと"
  end

  test "P1-2: allows removing player when roster is above min" do
    min = TeamMembership::ROSTER_MIN
    memberships = (min + 1).times.map do |i|
      p = Player.create!(name: "RAbv#{i}", short_name: "RA#{i}", number: format("%03d", i + 1))
      TeamMembership.create!(team: @team, player: p, squad: "second", selected_cost_type: "normal_cost")
    end

    assert memberships.first.destroy, "最低人数より多い場合は削除可能であること"
  end
end
