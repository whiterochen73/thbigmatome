class PitcherGameState < ApplicationRecord
  belongs_to :game
  belongs_to :pitcher, class_name: "Player"
  belongs_to :competition
  belongs_to :team

  validates :role, inclusion: { in: %w[starter reliever opener] }
  validates :result_category, inclusion: { in: %w[normal ko no_game long_loss] }, allow_nil: true
  validates :injury_check, inclusion: { in: %w[safe injured] }, allow_nil: true
end
