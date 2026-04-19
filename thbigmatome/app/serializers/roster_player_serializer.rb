class RosterPlayerSerializer < ActiveModel::Serializer
  attributes :team_membership_id, :player_id, :number, :player_name, :squad, :cooldown_until, :same_day_exempt, :cost, :selected_cost_type, :handedness, :position

  def number
    object.player.number
  end

  def handedness
    object.player.player_cards.first&.handedness
  end

  def position
    pc = object.player.player_cards.first
    is_fielder_only = object.selected_cost_type == "fielder_only_cost"
    if pc&.can_pitch? && !is_fielder_only
      "pitcher"
    else
      pc&.player_card_defenses&.first&.position&.downcase
    end
  end

  def player_name
    object.player.name
  end

  def cost
    @current_cost ||= Cost.current_cost
    return 0 unless @current_cost

    cost_player = object.player.cost_players.find do |cp|
      cp.cost_id == @current_cost.id && cp.player_card_id == object.player_card_id
    end
    cost_player ||= object.player.cost_players.find do |cp|
      cp.cost_id == @current_cost.id && cp.player_card_id.nil?
    end
    cost_player&.send(object.selected_cost_type) || 0
  end

  def selected_cost_type
    object.selected_cost_type
  end

  def cooldown_until
    cooldown_data[:cooldown_until]
  end

  def same_day_exempt
    cooldown_data[:same_day_exempt]
  end

  private

  def cooldown_data
    @cooldown_data ||= compute_cooldown_data
  end

  def compute_cooldown_data
    last_demotion = object.season_rosters
                      .where(squad: "second")
                      .order(registered_on: :desc, created_at: :desc)
                      .first

    return { cooldown_until: nil, same_day_exempt: false } unless last_demotion

    previous_promotion = object.season_rosters
                           .where(squad: "first")
                           .where(
                             "registered_on < :date OR (registered_on = :date AND created_at < :cat)",
                             date: last_demotion.registered_on, cat: last_demotion.created_at
                           )
                           .order(registered_on: :desc, created_at: :desc)
                           .first

    return { cooldown_until: nil, same_day_exempt: false } unless previous_promotion

    cooldown_end = (last_demotion.registered_on + 10.days).to_s
    same_day = previous_promotion.registered_on == last_demotion.registered_on
    { cooldown_until: cooldown_end, same_day_exempt: same_day }
  end
end
