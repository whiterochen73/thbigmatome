class TeamSerializer < ActiveModel::Serializer
  attributes :id, :name, :short_name, :is_active, :manager_id, :has_season
  # 必要であれば、Team詳細取得時にManager情報も埋め込む
  belongs_to :manager

  def has_season
    object.season.present?
  end
end