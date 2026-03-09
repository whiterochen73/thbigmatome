class TeamManager < ApplicationRecord
  belongs_to :team
  belongs_to :manager

  enum :role, { director: 0, coach: 1 }

  validates :role, presence: true
  validates :team_id, uniqueness: { scope: :role, if: -> { director? }, message: :director_already_exists }
  validate :manager_cannot_be_assigned_to_multiple_teams_in_same_league, on: [ :create, :update ]

  private

  def manager_cannot_be_assigned_to_multiple_teams_in_same_league
    # league系テーブル廃止(cmd_511 Phase 3)により、リーグベースの制約チェックは無効化
  end
end
