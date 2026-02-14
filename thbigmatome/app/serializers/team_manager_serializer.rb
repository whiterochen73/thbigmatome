class TeamManagerSerializer < ActiveModel::Serializer
  attributes :id, :team_id, :manager_id, :role

  belongs_to :manager
end
