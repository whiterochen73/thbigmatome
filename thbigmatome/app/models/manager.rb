class Manager < ApplicationRecord
  has_many :team_managers, dependent: :destroy
  has_many :teams, through: :team_managers
  enum :role, { director: 0, coach: 1 }
  validates :name, presence: true

  def active_director_team_count
    team_managers.joins(:team).where(role: :director, teams: { is_active: true }).count
  end
end
