class PlayerCardDetailSerializer < ActiveModel::Serializer
  attributes :id, :card_type,
             :speed, :bunt, :steal_start, :steal_end, :injury_rate,
             :is_pitcher, :is_relief_only,
             :starter_stamina, :relief_stamina,
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
        position: d.position,
        range_value: d.range_value,
        error_rank: d.error_rank,
        throwing: d.throwing
      }
    end
  end

  attribute :trait_list do
    object.player_card_traits.includes(:trait_definition).order(:sort_order).map do |t|
      {
        category: t.trait_definition.typical_role,
        name: t.trait_definition.name,
        description: t.trait_definition.description,
        role: t.role
      }
    end
  end

  attribute :ability_list do
    object.player_card_abilities.includes(:ability_definition).order(:sort_order).map do |a|
      {
        name: a.ability_definition.name,
        description: a.ability_definition.effect_description,
        role: a.role
      }
    end
  end

  def image_url
    return nil unless object.card_image.attached?

    Rails.application.routes.url_helpers.rails_blob_url(object.card_image, host: "localhost:3000")
  end
end
