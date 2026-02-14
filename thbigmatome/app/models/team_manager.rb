class TeamManager < ApplicationRecord
  belongs_to :team
  belongs_to :manager

  enum :role, { director: 0, coach: 1 }

  validates :role, presence: true
  validates :team_id, uniqueness: { scope: :role, if: -> { director? }, message: 'には既に監督が設定されています' }
  validate :manager_cannot_be_assigned_to_multiple_teams_in_same_league, on: [:create, :update]

  private

  def manager_cannot_be_assigned_to_multiple_teams_in_same_league
    return unless manager_id.present? && team.present?

    # 現在のチームが所属するリーグを取得
    current_league = team.leagues.first # チームは複数のリーグに所属する可能性があるが、コミッショナーモードでは1つのリーグを想定
    return unless current_league.present?

    # 同じリーグに所属する他のチームを取得
    other_teams_in_same_league = current_league.teams.where.not(id: team.id)

    # 同じマネージャーが他のチームに割り当てられているかチェック
    if TeamManager.where(manager_id: manager_id, team_id: other_teams_in_same_league.select(:id)).exists?
      errors.add(:manager_id, 'は同一リーグ内の複数のチームに兼任することはできません')
    end
  end
end
