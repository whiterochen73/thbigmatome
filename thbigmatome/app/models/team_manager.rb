class TeamManager < ApplicationRecord
  GAME_RULES = YAML.load_file(Rails.root.join("config", "game_rules.yaml")).freeze
  MAX_DIRECTOR_TEAMS = GAME_RULES.dig("rules", "manager", "max_active_teams_per_director", "value")

  belongs_to :team
  belongs_to :manager

  enum :role, { director: 0, coach: 1 }

  validates :role, presence: true
  validates :team_id, uniqueness: { scope: :role, if: -> { director? }, message: :director_already_exists }
  validate :manager_cannot_be_assigned_to_multiple_teams_in_same_league, on: [ :create, :update ]
  validate :director_team_limit, on: [ :create, :update ], if: -> { director? }

  private

  def manager_cannot_be_assigned_to_multiple_teams_in_same_league
    # league系テーブル廃止(cmd_511 Phase 3)により、リーグベースの制約チェックは無効化
  end

  def director_team_limit
    existing_count = TeamManager.joins(:team)
                                .where(manager_id: manager_id, role: :director)
                                .where(teams: { is_active: true })
                                .where.not(id: id)
                                .count
    if existing_count >= MAX_DIRECTOR_TEAMS
      errors.add(:manager_id,
        I18n.t("activerecord.errors.models.team_manager.director_team_limit"))
    end
  end
end
