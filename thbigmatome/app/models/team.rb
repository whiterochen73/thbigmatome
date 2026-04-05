class Team < ApplicationRecord
  COST_LIMIT_CONFIG = YAML.load_file(Rails.root.join("config", "cost_limits.yml")).freeze
  TEAM_TOTAL_MAX_COST = COST_LIMIT_CONFIG["team_total_max_cost"]

  belongs_to :user, optional: true

  has_one :season, dependent: :restrict_with_error
  has_many :team_memberships, dependent: :destroy
  has_many :players, through: :team_memberships

  has_many :competition_entries, dependent: :destroy
  has_many :competitions, through: :competition_entries
  has_many :home_games, class_name: "Game", foreign_key: :home_team_id, dependent: :destroy, inverse_of: :home_team
  has_many :visitor_games, class_name: "Game", foreign_key: :visitor_team_id, dependent: :destroy, inverse_of: :visitor_team
  has_many :pitcher_game_states, dependent: :destroy
  has_many :imported_stats, dependent: :destroy

  has_many :lineup_templates, dependent: :destroy
  has_one :squad_text_setting, dependent: :destroy
  has_one :game_lineup, dependent: :destroy

  has_many :team_managers, dependent: :destroy
  has_one :director_team_manager, -> { where(role: :director) }, class_name: "TeamManager", dependent: :destroy
  has_one :director, through: :director_team_manager, source: :manager
  has_many :coach_team_managers, -> { where(role: :coach) }, class_name: "TeamManager", dependent: :destroy
  has_many :coaches, through: :coach_team_managers, source: :manager

  VALID_TEAM_TYPES = %w[normal hachinai].freeze
  NATIVE_SERIES = {
    "normal"   => %w[touhou].freeze,
    "hachinai" => %w[hachinai tamayomi].freeze
  }.freeze

  validates :name, presence: true
  validates :team_type, inclusion: { in: VALID_TEAM_TYPES }

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

  # 1軍の外の世界枠選手（team_type に応じたネイティブ series 以外が外の世界枠）
  def outside_world_first_squad_memberships
    native = NATIVE_SERIES[team_type] || NATIVE_SERIES["normal"]
    memberships = team_memberships.where(squad: "first")
                                  .includes(:player, { player: :player_cards }, player_card: :card_set)
    memberships.select do |tm|
      effective_series = tm.player_card&.card_set&.series.presence || tm.player.series
      effective_series.present? && !native.include?(effective_series)
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
  # player_cards.card_type で判定。pitcherカードがあれば投手扱い
  def validate_outside_world_balance
    ow_memberships = outside_world_first_squad_memberships
    return true if ow_memberships.size < OUTSIDE_WORLD_LIMIT

    has_pitcher = ow_memberships.any? { |tm| tm.player.player_cards.any? { |pc| pc.card_type == "pitcher" } }
    has_fielder = ow_memberships.any? { |tm| tm.player.player_cards.any? { |pc| pc.card_type == "batter" } }

    unless has_pitcher && has_fielder
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
