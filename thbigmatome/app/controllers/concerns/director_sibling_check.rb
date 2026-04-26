module DirectorSiblingCheck
  extend ActiveSupport::Concern

  class OverlapError < StandardError; end

  private

  def check_director_sibling_overlap!(team, manager_id)
    sibling_team_ids = TeamManager.where(manager_id: manager_id, role: :director)
                                  .where.not(team_id: team.id)
                                  .pluck(:team_id)
    return if sibling_team_ids.empty?

    if TeamMembership.where(team_id: sibling_team_ids, player_id: team.team_memberships.pluck(:player_id)).exists?
      raise OverlapError, "Director変更不可: 新しい監督の他チームと選手が重複しています"
    end
  end
end
