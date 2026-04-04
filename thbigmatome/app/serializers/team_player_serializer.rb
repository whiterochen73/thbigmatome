class TeamPlayerSerializer < PlayerSerializer
  attributes :selected_cost_type, :current_cost, :excluded_from_team_total, :display_name,
             :player_card_id

  def membership
    @membership ||= object.team_memberships.find_by(team_id: @instance_options[:team].id)
  end

  def selected_cost_type
    membership.selected_cost_type
  end

  def current_cost
    cost_type = membership.selected_cost_type
    cost_player_record = object.cost_players.find_by(cost_id: @instance_options[:cost_list_id])
    cost_player_record&.send(cost_type)
  end

  def excluded_from_team_total
    membership.excluded_from_team_total
  end

  def display_name
    membership.display_name
  end

  def player_card_id
    membership.player_card_id
  end

  attribute :player_card_info do
    pc = membership.player_card
    next nil unless pc

    {
      id: pc.id,
      card_type: pc.card_type,
      card_set_name: pc.card_set.name,
      card_set_id: pc.card_set_id,
      variant: pc.variant
    }
  end
end
