# 外の世界枠の選手（normal チームでは東方以外）を 1 人足す spec 用のヘルパー（cmd_1808）。
# カードは tamayomi2 セット（series tamayomi）。pm2026 のカードは同名の別選手を引く Player#fallback_hachinai_player が選手ごとに問い合わせるので使わない。
# 主な位置は守備位置の 1 つ目（PlayerCard#primary_position）。
#   kind:
#     :pitcher               主な位置が投手（P）のカード（card_type pitcher）
#     :fielder               主な位置が野手（SS）のカード（card_type batter）
#     :pitcher_card_infielder card_type は pitcher だが、主な位置が内野手（3B、続いて P）のカード（天弓千亦・涼宮ハルヒと同じ型）
#     :batter_card_pitcher   card_type は batter だが、主な位置が投手（P）のカード
#     :two_way               ハチナイ二刀流の選手（hachinai_two_way?）。野手カードを登録。契約は省略時 two_way_cost（両方に数える）
#     :no_card               カードを登録していない
#   cost_type: 契約。省略時は :two_way は two_way_cost、それ以外は normal_cost
#   season を渡すと、1軍の記録（season_rosters）も足す（ダッシュボード・ロスター画面は記録から 1軍を決めるため）
module OutsideWorldMemberHelper
  def add_outside_world_member(team, kind, cost_type: nil, squad: "first", season: nil, registered_on: Date.new(2026, 5, 1))
    @outside_world_card_sets ||= {}
    outside_set = @outside_world_card_sets[:outside] ||= create(:card_set, set_type: "tamayomi2")
    hachinai_set = @outside_world_card_sets[:hachinai] ||= create(:card_set, set_type: "hachinai61", year: 2061)
    player = create(:player, series: "tamayomi", number: kind == :two_way ? "34" : "50")
    card =
      case kind
      when :pitcher then add_card(player, outside_set, "pitcher", %w[P])
      when :fielder then add_card(player, outside_set, "batter", %w[SS])
      when :pitcher_card_infielder then add_card(player, outside_set, "pitcher", %w[3B P])
      when :batter_card_pitcher then add_card(player, outside_set, "batter", %w[P OF])
      when :two_way then add_card(player, hachinai_set, "batter", %w[SS])
      when :no_card then nil
      else raise ArgumentError, "unknown kind: #{kind}"
      end
    cost_type ||= kind == :two_way ? "two_way_cost" : "normal_cost"
    membership = create(:team_membership, team: team, player: player, player_card: card, squad: squad, selected_cost_type: cost_type)
    create(:season_roster, season: season, team_membership: membership, squad: "first", registered_on: registered_on) if season && squad == "first"
    membership
  end

  # 守備位置を並べた順（id 順）に足したカード。1 つ目が主な位置
  def add_card(player, card_set, card_type, positions)
    card = create(:player_card, player: player, card_set: card_set, card_type: card_type, is_pitcher: card_type == "pitcher")
    positions.each { |position| card.player_card_defenses.create!(position: position, range_value: 3, error_rank: "C") }
    card
  end
end

RSpec.configure { |config| config.include OutsideWorldMemberHelper }
