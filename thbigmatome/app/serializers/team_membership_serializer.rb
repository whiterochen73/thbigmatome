class TeamMembershipSerializer < ActiveModel::Serializer
  attributes :id, :team_id, :player_id, :player_card_id, :squad, :selected_cost_type, :excluded_from_team_total, :display_name

  belongs_to :player

  attribute :player_card_info do
    pc = object.player_card
    next nil unless pc

    {
      id: pc.id,
      card_type: pc.card_type,
      card_set_name: pc.card_set.name,
      card_set_id: pc.card_set_id
    }
  end
end
