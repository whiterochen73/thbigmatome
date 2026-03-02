class PlayerCardDetailSerializer < ActiveModel::Serializer
  attributes :id, :card_type, :handedness,
             :speed, :bunt, :steal_start, :steal_end, :injury_rate,
             :is_pitcher, :is_relief_only, :is_closer,
             :is_switch_hitter, :is_dual_wielder,
             :starter_stamina, :relief_stamina,
             :biorhythm_period,
             :abilities, :unique_traits, :injury_traits,
             :batting_table, :pitching_table,
             :card_image_path, :image_url

  attribute :player do
    { id: object.player.id, name: object.player.name, number: object.player.number }
  end

  attribute :card_set do
    { id: object.card_set.id, name: object.card_set.name }
  end

  attribute :defenses do
    object.player_card_defenses.order(:position).map do |d|
      {
        id: d.id,
        position: d.position,
        range_value: d.range_value,
        error_rank: d.error_rank,
        throwing: d.throwing
      }
    end
  end

  attribute :trait_list do
    object.player_card_traits.includes(:trait_definition, :condition).order(:sort_order).map do |t|
      {
        id: t.id,
        category: t.trait_definition.typical_role,
        name: t.trait_definition.name,
        description: t.trait_definition.description,
        role: t.role,
        condition_name: t.condition&.name,
        condition_description: t.condition&.description
      }
    end
  end

  attribute :ability_list do
    object.player_card_abilities.includes(:ability_definition, :condition).order(:sort_order).map do |a|
      {
        id: a.id,
        name: a.ability_definition.name,
        description: a.ability_definition.effect_description,
        role: a.role,
        condition_name: a.condition&.name,
        condition_description: a.condition&.description
      }
    end
  end

  attribute :cost do
    current_cost = Cost.current_cost
    next nil unless current_cost
    cp = object.player.cost_players.find { |c| c.cost_id == current_cost.id }
    cp&.normal_cost
  end

  def image_url
    return nil unless object.card_image.attached?

    Rails.application.routes.url_helpers.rails_blob_url(object.card_image, host: "localhost:3000")
  end
end
