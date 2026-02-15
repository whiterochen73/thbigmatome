class RosterPlayerSerializer < ActiveModel::Serializer
  attributes :team_membership_id, :player_id, :number, :player_name, :squad, :cooldown_until, :cost, :selected_cost_type, :throwing_hand, :batting_hand

  def number
    object.player.number
  end

  def throwing_hand
    object.player.throwing_hand
  end

  def batting_hand
    object.player.batting_hand
  end

  def player_name
    object.player.name
  end

  def cost
    @current_cost ||= Cost.current_cost
    return 0 unless @current_cost

    cost_player = object.player.cost_players.find { |cp| cp.cost_id == @current_cost.id }
    cost_player&.send(object.selected_cost_type) || 0
  end

  def selected_cost_type
    object.selected_cost_type
  end

  def cooldown_until
    # This logic should ideally be in a service object or the model
    # For now, a simplified version:
    # Find the last time this player moved from first to second squad
    last_moved_from_first_to_second = object.season_rosters
                                        .where(squad: "second")
                                        .order(registered_on: :desc, created_at: :desc)
                                        .first

    if last_moved_from_first_to_second
      previous_entry = object.season_rosters
                            .where("registered_on < ?", last_moved_from_first_to_second.registered_on)
                            .order(registered_on: :desc, created_at: :desc)
                            .first
      if previous_entry && previous_entry.squad == "first"
        return (last_moved_from_first_to_second.registered_on + 10.days).to_s # Return as string
      end
    end
    nil
  end
end
