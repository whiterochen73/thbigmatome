class TeamMembership < ApplicationRecord
  belongs_to :team
  belongs_to :player
  has_many :season_rosters
  has_many :player_absences, dependent: :restrict_with_error

  validates :squad, inclusion: { in: %w[first second] }
  validates :selected_cost_type, presence: true, inclusion: { in: %w[normal_cost relief_only_cost pitcher_only_cost fielder_only_cost two_way_cost] }

  validate :player_not_in_director_sibling_team, on: :create

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
end
