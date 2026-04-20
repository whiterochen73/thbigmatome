class TeamMembership < ApplicationRecord
  belongs_to :team
  belongs_to :player
  belongs_to :player_card, optional: true
  has_many :season_rosters
  has_many :player_absences, dependent: :restrict_with_error

  attr_accessor :skip_commissioner_validation

  validates :squad, inclusion: { in: %w[first second] }
  validates :selected_cost_type, presence: true, inclusion: { in: %w[normal_cost relief_only_cost pitcher_only_cost fielder_only_cost two_way_cost] }

  validate :player_not_in_director_sibling_team, on: :create, unless: :skip_commissioner_validation

  scope :included_in_team_total, -> { where(excluded_from_team_total: false) }
  scope :excluded_from_team_total, -> { where(excluded_from_team_total: true) }

  def selected_cost_value(cost_list)
    cost_list_id = extract_cost_list_id(cost_list)
    return 0 unless cost_list_id

    preferred_cost_types.each do |cost_type|
      value = cost_value_for(cost_type, cost_list_id)
      return value if value.present?
    end

    0
  end

  def pitcher_role?
    return false if selected_cost_type == "fielder_only_cost"
    return true if player_card&.can_pitch?

    player&.hachinai_two_way? && %w[normal_cost pitcher_only_cost two_way_cost].include?(selected_cost_type)
  end

  def fielder_role?
    return false if selected_cost_type == "pitcher_only_cost"
    return true if player_card.present? && !player_card.can_pitch?

    player&.hachinai_two_way?
  end

  def starter_pitcher_role?
    return false unless pitcher_role?

    player_card&.starter_stamina.present? && player_card.starter_stamina >= 4
  end

  def relief_only_role?
    return false unless pitcher_role?

    player_card&.is_relief_only || false
  end

  def roster_position
    return "pitcher" if pitcher_role?

    player_card&.player_card_defenses&.first&.position&.downcase
  end

  private

  def preferred_cost_types
    return [ selected_cost_type ] unless player&.hachinai_two_way?

    case selected_cost_type
    when "fielder_only_cost"
      %w[fielder_only_cost two_way_cost pitcher_only_cost normal_cost]
    when "pitcher_only_cost"
      %w[pitcher_only_cost two_way_cost fielder_only_cost normal_cost]
    when "two_way_cost"
      %w[two_way_cost pitcher_only_cost fielder_only_cost normal_cost]
    when "normal_cost"
      if player_card&.can_pitch?
        %w[pitcher_only_cost two_way_cost fielder_only_cost normal_cost]
      else
        %w[fielder_only_cost two_way_cost pitcher_only_cost normal_cost]
      end
    else
      [ selected_cost_type ]
    end
  end

  def extract_cost_list_id(cost_list)
    return cost_list.id if cost_list.respond_to?(:id)
    return cost_list if cost_list.is_a?(Integer)

    nil
  end

  def cost_value_for(cost_type, cost_list_id)
    player.cost_value_for_types([ cost_type ], cost_list_id, exact_player_card_id: player_card_id).presence
  end

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
