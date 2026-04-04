class TeamMembership < ApplicationRecord
  GAME_RULES = YAML.load_file(Rails.root.join("config", "game_rules.yaml")).freeze
  ROSTER_MAX = GAME_RULES.dig("rules", "team_composition", "roster", "max")
  ROSTER_MIN = GAME_RULES.dig("rules", "team_composition", "roster", "min")

  belongs_to :team
  belongs_to :player
  belongs_to :player_card, optional: true
  has_many :season_rosters
  has_many :player_absences, dependent: :restrict_with_error

  # skip_commissioner_validation は attr_accessor のため mass assignment では設定不可
  # 使用箇所: app/controllers/api/v1/team_players_controller.rb（コントローラ層でのみ設定）
  attr_accessor :skip_commissioner_validation

  validates :squad, inclusion: { in: %w[first second] }
  validates :selected_cost_type, presence: true, inclusion: { in: %w[normal_cost relief_only_cost pitcher_only_cost fielder_only_cost two_way_cost] }

  # P1-1: on: [:create, :update] でupdateでも排他チェックが走るようにする
  validate :player_not_in_director_sibling_team, on: [ :create, :update ], unless: :skip_commissioner_validation

  # P1-2: ロスター人数上限チェック（game_rules.yaml roster_max 参照）
  validate :validate_roster_max, on: :create

  # P1-2: ロスター人数下限チェック（game_rules.yaml roster_min 参照）
  before_destroy :check_roster_min

  scope :included_in_team_total, -> { where(excluded_from_team_total: false) }
  scope :excluded_from_team_total, -> { where(excluded_from_team_total: true) }

  private

  def player_not_in_director_sibling_team
    return unless team

    director_tm = team.director_team_manager
    return unless director_tm

    director_id = director_tm.manager_id

    sibling_team_ids = TeamManager.joins(:team)
                                  .where(manager_id: director_id, role: :director)
                                  .where(teams: { is_active: true })
                                  .where.not(team_id: team.id)
                                  .pluck(:team_id)
    return if sibling_team_ids.empty?

    if TeamMembership.where(team_id: sibling_team_ids, player_id: player_id).exists?
      sibling_team = Team.joins(:team_managers)
                         .where(team_managers: { manager_id: director_id, role: :director })
                         .where.not(id: team.id)
                         .first
      errors.add(:player_id,
        I18n.t("activerecord.errors.models.team_membership.player_in_sibling_team",
               player_name: player&.name,
               team_name: sibling_team&.name))
    end
  end

  def validate_roster_max
    return unless team
    if team.team_memberships.count >= ROSTER_MAX
      errors.add(:base,
        I18n.t("activerecord.errors.models.team_membership.roster_max_exceeded", max: ROSTER_MAX))
    end
  end

  def check_roster_min
    return unless team
    # 試合が1試合も行われていない場合は下限チェックをスキップ（game_rules.yaml roster.exception）
    return if no_confirmed_games?
    if team.team_memberships.count <= ROSTER_MIN
      errors.add(:base,
        I18n.t("activerecord.errors.models.team_membership.roster_min_required", min: ROSTER_MIN))
      throw :abort
    end
  end

  def no_confirmed_games?
    !team.home_games.where(status: "confirmed").exists? &&
      !team.visitor_games.where(status: "confirmed").exists?
  end
end
