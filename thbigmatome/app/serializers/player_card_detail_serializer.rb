class PlayerCardDetailSerializer < ActiveModel::Serializer
  attributes :id, :card_type,
             :speed, :bunt, :steal_start, :steal_end, :injury_rate,
             :is_pitcher, :is_relief_only, :is_closer,
             :is_switch_hitter, :is_dual_wielder,
             :starter_stamina, :relief_stamina,
             :biorhythm_period,
             :unique_traits, :injury_traits,
             :batting_table, :pitching_table,
             :image_url

  attribute :handedness do
    object.handedness
  end

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
    cp = object.player.cost_players.max_by(&:cost_id)
    cp&.normal_cost
  end

  attribute :costs do
    object.player.cost_players.includes(:cost).map do |cp|
      {
        cost_name: cp.cost.name,
        is_current: cp.cost.end_date.nil?,
        normal_cost: cp.normal_cost,
        pitcher_only_cost: cp.pitcher_only_cost,
        fielder_only_cost: cp.fielder_only_cost,
        relief_only_cost: cp.relief_only_cost,
        two_way_cost: cp.two_way_cost
      }
    end
  end

  def image_url
    return nil unless object.card_image.attached?

    host = ENV.fetch("APP_HOST", "localhost:3000")
    Rails.application.routes.url_helpers.rails_blob_url(
      object.card_image, host: host, protocol: Rails.env.production? ? "https" : "http"
    )
  end
end
