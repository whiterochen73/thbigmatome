class Competition < ApplicationRecord
  COMPETITION_TYPES = %w[league_pennant tournament].freeze

  has_many :competition_entries, dependent: :destroy
  has_many :teams, through: :competition_entries

  has_many :games, dependent: :destroy
  has_many :pitcher_game_states, dependent: :destroy
  has_many :imported_stats, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :year }
  validates :competition_type, presence: true, inclusion: { in: COMPETITION_TYPES }
  validates :year, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
