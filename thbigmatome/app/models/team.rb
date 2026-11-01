class Team < ApplicationRecord
  COST_LIMIT_CONFIG = YAML.load_file(Rails.root.join("config", "cost_limits.yml")).freeze
  TEAM_TOTAL_MAX_COST = COST_LIMIT_CONFIG["team_total_max_cost"]

  belongs_to :user, optional: true

  has_one :season, dependent: :restrict_with_error
  # 在籍中のチーム編成。放出された選手の行は残る（登板・離脱・昇降格の記録が指す先）が、ここには出さない。
  # 過去の時点を導く時（RosterState・変更記録）は放出済みを含む all_team_memberships を使う（cmd_1784 段2）
  has_many :team_memberships, -> { where(on_team: true) }, inverse_of: :team
  has_many :all_team_memberships, class_name: "TeamMembership", dependent: :destroy, inverse_of: :team
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

  # 外の世界枠の選手か（team_type に応じたネイティブ series 以外。登録カードの series を優先し、無ければ選手の series）
  def outside_world_membership?(membership)
    native = NATIVE_SERIES[team_type] || NATIVE_SERIES["normal"]
    effective_series = membership.player_card&.card_set&.series.presence || membership.player.series
    effective_series.present? && !native.include?(effective_series)
  end

  # 1軍の外の世界枠選手
  def outside_world_first_squad_memberships(first_squad_memberships = nil)
    memberships = first_squad_memberships ||
      team_memberships.where(squad: "first")
                      .includes(:player, { player: :player_cards }, player_card: :card_set)
    memberships.select { |tm| outside_world_membership?(tm) }
  end

  # 外の世界枠の選手を、投手だけに数える（pitcher_only）・野手だけに数える（fielder_only）・両方に数える（two_way）に分けて数える。
  # 区分は TeamMembership#pitcher_fielder_kind（pitcher_role? / fielder_role? の組み合わせ）。
  # balance_ok は outside_world_balance_ok? と同じ
  def self.outside_world_breakdown(outside_world_memberships)
    kinds = outside_world_memberships.map(&:pitcher_fielder_kind)
    {
      pitcher_only: kinds.count(:pitcher_only),
      fielder_only: kinds.count(:fielder_only),
      two_way: kinds.count(:two_way),
      balance_ok: outside_world_balance_ok?(kinds)
    }
  end

  # 4 人以上の時は、投手に数える人（投手のみ・二刀流）と野手に数える人（野手のみ・二刀流）が 1 人以上いること。3 人以下は内訳を問わない。
  # kinds: 外の世界枠の各選手の TeamMembership#pitcher_fielder_kind
  def self.outside_world_balance_ok?(kinds)
    return true if kinds.size < OUTSIDE_WORLD_LIMIT

    kinds.any? { |k| %i[pitcher_only two_way].include?(k) } && kinds.any? { |k| %i[fielder_only two_way].include?(k) }
  end

  # 外の世界枠: 最大4人チェック
  def validate_outside_world_limit(first_squad_memberships = nil)
    ow_memberships = outside_world_first_squad_memberships(first_squad_memberships)
    if ow_memberships.size > OUTSIDE_WORLD_LIMIT
      errors.add(:base, I18n.t("activerecord.errors.models.team.outside_world.limit_exceeded",
        count: ow_memberships.size, limit: OUTSIDE_WORLD_LIMIT))
      false
    else
      true
    end
  end

  # 外の世界枠: 4人のとき投手/野手混在必須チェック（内訳の数え方は Team.outside_world_breakdown）
  def validate_outside_world_balance(first_squad_memberships = nil)
    ow_memberships = outside_world_first_squad_memberships(first_squad_memberships)
    return true if self.class.outside_world_balance_ok?(ow_memberships.map(&:pitcher_fielder_kind))

    errors.add(:base, I18n.t("activerecord.errors.models.team.outside_world.balance_required"))
    false
  end

  private

  def calculate_included_team_cost(cost_list_id)
    included_memberships = team_memberships.included_in_team_total.includes(player: :cost_players)
    included_memberships.sum do |tm|
      tm.selected_cost_value(cost_list_id)
    end
  end
end
