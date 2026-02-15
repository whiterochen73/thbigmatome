class Team < ApplicationRecord
  COST_LIMIT_CONFIG = YAML.load_file(Rails.root.join("config", "cost_limits.yml")).freeze
  TEAM_TOTAL_MAX_COST = COST_LIMIT_CONFIG["team_total_max_cost"]

  has_one :season, dependent: :restrict_with_error
  has_many :team_memberships, dependent: :destroy
  has_many :players, through: :team_memberships

  has_many :league_memberships, dependent: :destroy
  has_many :leagues, through: :league_memberships

  has_many :team_managers, dependent: :destroy
  has_one :director_team_manager, -> { where(role: :director) }, class_name: "TeamManager", dependent: :destroy
  has_one :director, through: :director_team_manager, source: :manager
  has_many :coach_team_managers, -> { where(role: :coach) }, class_name: "TeamManager", dependent: :destroy
  has_many :coaches, through: :coach_team_managers, source: :manager

  validates :name, presence: true

  # 1軍登録人数に対応するコスト上限を返す。人数不足の場合はnil
  def self.first_squad_cost_limit_for_count(count)
    tier = COST_LIMIT_CONFIG["first_squad_tiers"].find { |t| count >= t["min_players"] }
    tier ? tier["max_cost"] : nil
  end

  def self.first_squad_minimum_players
    COST_LIMIT_CONFIG["first_squad_minimum_players"]
  end

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

  private

  def calculate_included_team_cost(cost_list_id)
    included_memberships = team_memberships.included_in_team_total.includes(player: :cost_players)
    included_memberships.sum do |tm|
      cost_player = tm.player.cost_players.find { |cp| cp.cost_id == cost_list_id }
      cost_player ? (cost_player.send(tm.selected_cost_type) || 0) : 0
    end
  end
end
