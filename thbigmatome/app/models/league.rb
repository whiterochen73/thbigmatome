class League < ApplicationRecord
  has_many :league_memberships, dependent: :destroy
  has_many :league_seasons, dependent: :destroy
  has_many :teams, through: :league_memberships

  validates :name, presence: true
  validates :num_teams, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :num_games, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
