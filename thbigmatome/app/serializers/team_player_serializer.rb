class TeamPlayerSerializer < PlayerSerializer
  attributes :selected_cost_type, :current_cost, :excluded_from_team_total

  def selected_cost_type
    object.team_memberships.find_by(team_id: @instance_options[:team].id).selected_cost_type
  end

  def current_cost
    cost_type = object.team_memberships.find_by(team_id: @instance_options[:team].id).selected_cost_type
    # 関連するCostPlayerからコストを取得
    cost_player_record = object.cost_players.find_by(cost_id: @instance_options[:cost_list_id])
    cost_player_record&.send(cost_type)
  end

  def excluded_from_team_total
    object.team_memberships.find_by(team_id: @instance_options[:team].id).excluded_from_team_total
  end
end
