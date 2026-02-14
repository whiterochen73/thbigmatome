class TeamMembershipSerializer < ActiveModel::Serializer
  attributes :id, :team_id, :player_id, :squad, :selected_cost_type

  belongs_to :player
end
