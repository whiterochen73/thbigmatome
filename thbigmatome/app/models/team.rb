class Team < ApplicationRecord
  COST_LIMIT_CONFIG = YAML.load_file(Rails.root.join("config", "cost_limits.yml")).freeze

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

  # 除外フラグOFFの選手数（コスト上限テーブル参照用）
  def eligible_player_count
    team_memberships.included_in_team_total.count
  end

  # 登録人数に対応するコスト上限を返す。人数不足の場合はnil
  def self.cost_limit_for_count(count)
    tier = COST_LIMIT_CONFIG["tiers"].find { |t| count >= t["min_players"] }
    tier ? tier["max_cost"] : nil
  end

  def self.minimum_players
    COST_LIMIT_CONFIG["minimum_players"]
  end

  # 対象人数が最低人数未満ならエラーを追加
  def validate_minimum_players
    count = eligible_player_count
    return true if count == 0 # 空チームは許可

    minimum = self.class.minimum_players
    if count < minimum
      errors.add(:base, I18n.t("activerecord.errors.models.team.cost_limit.below_minimum_players", count: count, minimum: minimum))
      false
    else
      true
    end
  end

  # チーム全体コスト（除外選手を除く）が上限以下かチェック
  def validate_cost_within_limit(cost_list_id)
    count = eligible_player_count
    limit = self.class.cost_limit_for_count(count)
    return true unless limit # minimum_players バリデーションで処理

    total_cost = calculate_included_team_cost(cost_list_id)
    if total_cost > limit
      errors.add(:base, I18n.t("activerecord.errors.models.team.cost_limit.cost_exceeds_limit", cost: total_cost, limit: limit))
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
