class TeamMembershipSerializer < ActiveModel::Serializer
  attributes :id, :team_id, :player_id, :squad, :selected_cost_type, :excluded_from_team_total

  belongs_to :player
end
