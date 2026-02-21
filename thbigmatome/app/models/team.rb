class Team < ApplicationRecord
  COST_LIMIT_CONFIG = YAML.load_file(Rails.root.join("config", "cost_limits.yml")).freeze
  TEAM_TOTAL_MAX_COST = COST_LIMIT_CONFIG["team_total_max_cost"]

  has_one :season, dependent: :restrict_with_error
  has_many :team_memberships, dependent: :destroy
  has_many :players, through: :team_memberships

  has_many :league_memberships, dependent: :destroy
  has_many :leagues, through: :league_memberships

  has_many :competition_entries, dependent: :destroy
  has_many :competitions, through: :competition_entries
  has_many :home_games, class_name: "Game", foreign_key: :home_team_id, dependent: :destroy, inverse_of: :home_team
  has_many :visitor_games, class_name: "Game", foreign_key: :visitor_team_id, dependent: :destroy, inverse_of: :visitor_team
  has_many :pitcher_game_states, dependent: :destroy
  has_many :imported_stats, dependent: :destroy

  has_many :team_managers, dependent: :destroy
  has_one :director_team_manager, -> { where(role: :director) }, class_name: "TeamManager", dependent: :destroy
  has_one :director, through: :director_team_manager, source: :manager
  has_many :coach_team_managers, -> { where(role: :coach) }, class_name: "TeamManager", dependent: :destroy
  has_many :coaches, through: :coach_team_managers, source: :manager

  validates :name, presence: true

  # シーズンが存在するかどうか（TopMenu等のUI表示で使用）
  def has_season
    season.present?
  end

  # 1軍登録人数に対応するコスト上限を返す。人数不足の場合はnil
  def self.first_squad_cost_limit_for_count(count)
    tier = COST_LIMIT_CONFIG["first_squad_tiers"].find { |t| count >= t["min_players"] }
    tier ? tier["max_cost"] : nil
  end

  def self.first_squad_minimum_players
    COST_LIMIT_CONFIG["first_squad_minimum_players"]
  end

  OUTSIDE_WORLD_LIMIT = 4

  # チーム全体コスト（除外選手を除く）が上限（200固定）以下かチェック
  def validate_team_total_cost(cost_list_id)
    total_cost = calculate_included_team_cost(cost_list_id)
    if total_cost > TEAM_TOTAL_MAX_COST
      errors.add(:base, I18n.t("activerecord.errors.models.team.cost_limit.cost_exceeds_limit", cost: total_cost, limit: TEAM_TOTAL_MAX_COST))
      false
    else
      true
    end
  end

  # 1軍の外の世界枠選手（outside_worldカテゴリのタイプを持つ選手）
  def outside_world_first_squad_memberships
    team_memberships.where(squad: "first").includes(player: :player_types).select do |tm|
      tm.player.player_types.any? { |pt| pt.category == "outside_world" }
    end
  end

  # 外の世界枠: 最大4人チェック
  def validate_outside_world_limit
    ow_memberships = outside_world_first_squad_memberships
    if ow_memberships.size > OUTSIDE_WORLD_LIMIT
      errors.add(:base, I18n.t("activerecord.errors.models.team.outside_world.limit_exceeded",
        count: ow_memberships.size, limit: OUTSIDE_WORLD_LIMIT))
      false
    else
      true
    end
  end

  # 外の世界枠: 4人のとき投手/野手混在必須チェック
  # 二刀流選手は投手・野手どちらにもカウント可能
  def validate_outside_world_balance
    ow_memberships = outside_world_first_squad_memberships
    return true if ow_memberships.size < OUTSIDE_WORLD_LIMIT

    two_way_type = PlayerType.find_by(name: "二刀流")
    two_way_count = 0
    pure_pitcher_count = 0
    pure_fielder_count = 0

    ow_memberships.each do |tm|
      is_two_way = two_way_type && tm.player.player_types.include?(two_way_type)
      if is_two_way
        two_way_count += 1
      elsif tm.player.is_pitcher
        pure_pitcher_count += 1
      else
        pure_fielder_count += 1
      end
    end

    pitcher_capable = pure_pitcher_count + two_way_count >= 1
    fielder_capable = pure_fielder_count + two_way_count >= 1

    unless pitcher_capable && fielder_capable
      errors.add(:base, I18n.t("activerecord.errors.models.team.outside_world.balance_required"))
      false
    else
      true
    end
  end

  private

  def calculate_included_team_cost(cost_list_id)
    included_memberships = team_memberships.included_in_team_total.includes(player: :cost_players)
    included_memberships.sum do |tm|
      cost_player = tm.player.cost_players.find { |cp| cp.cost_id == cost_list_id }
      cost_player ? (cost_player.send(tm.selected_cost_type) || 0) : 0
    end
  end
end
