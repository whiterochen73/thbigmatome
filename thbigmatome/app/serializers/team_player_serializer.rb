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
    cost_list_id = @instance_options[:cost_list_id]&.to_i
    return nil unless cost_list_id

    membership.selected_cost_value(cost_list_id)
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

  attribute :available_cost_types do
    object.available_cost_types
  end

  attribute :player_card_info do
    pc = membership.player_card
    next nil unless pc

    {
      id: pc.id,
      card_type: pc.card_type,
      card_set_name: pc.card_set.name,
      card_set_id: pc.card_set_id
    }
  end
end
