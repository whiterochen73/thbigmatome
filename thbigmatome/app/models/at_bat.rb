class AtBat < ApplicationRecord
  belongs_to :game
  belongs_to :batter, class_name: "Player"
  belongs_to :pitcher, class_name: "Player"
  belongs_to :pinch_hit_for, class_name: "Player", optional: true

  enum :status, { draft: 0, confirmed: 1 }

  validates :seq, presence: true,
                  numericality: { only_integer: true, greater_than: 0 },
                  uniqueness: { scope: :game_id }
  validates :half, inclusion: { in: %w[top bottom] }
  validates :play_type, inclusion: { in: %w[normal bunt squeeze safety_bunt hit_and_run] }
  validates :result_code, presence: true
  validates :inning, numericality: { only_integer: true, greater_than: 0 }
  validates :outs, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 2 }
  validates :outs_after, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 3 }
end
