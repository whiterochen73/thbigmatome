class Manager < ApplicationRecord
  has_many :team_managers, dependent: :destroy
  has_many :teams, through: :team_managers
  enum :role, { director: 0, coach: 1 }
  validates :name, presence: true
end
