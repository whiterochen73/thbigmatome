class TeamSerializer < ActiveModel::Serializer
  attributes :id, :name, :short_name, :is_active, :has_season, :user_id
  # 必要であれば、Team詳細取得時にManager情報も埋め込む
  has_one :director
  has_many :coaches

  def has_season
    object.season.present?
  end
end
