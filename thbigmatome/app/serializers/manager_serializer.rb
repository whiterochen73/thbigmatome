class ManagerSerializer < ActiveModel::Serializer
  attributes :id, :name, :short_name, :irc_name , :user_id

  # Manager詳細取得時に、紐づくTeamもJSONに含める
  has_many :teams
end
