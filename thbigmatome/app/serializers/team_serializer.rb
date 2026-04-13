class TeamSerializer < ActiveModel::Serializer
  attributes :id, :name, :short_name, :is_active, :has_season, :user_id, :team_type,
             :last_game_real_date, :last_game_date, :season_current_date
  # 必要であれば、Team詳細取得時にManager情報も埋め込む
  has_one :director
  has_many :coaches

  def has_season
    object.season.present?
  end

  def last_game_real_date
    object.respond_to?(:last_game_real_date) ? object.last_game_real_date : nil
  end

  def last_game_date
    object.respond_to?(:last_game_date) ? object.last_game_date : nil
  end

  def season_current_date
    object.respond_to?(:season_current_date) ? object.season_current_date : nil
  end
end
