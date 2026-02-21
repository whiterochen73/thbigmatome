class Game < ApplicationRecord
  belongs_to :competition
  belongs_to :home_team, class_name: "Team"
  belongs_to :visitor_team, class_name: "Team"
  belongs_to :stadium
  has_many :at_bats, dependent: :destroy
  has_many :game_events, dependent: :destroy
  has_many :pitcher_game_states, dependent: :destroy

  validates :status, inclusion: { in: %w[draft confirmed] }
  validates :source, inclusion: { in: %w[live log_import summary] }
end
