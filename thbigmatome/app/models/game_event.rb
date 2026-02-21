class GameEvent < ApplicationRecord
  belongs_to :game

  validates :event_type, presence: true
  validates :inning, numericality: { only_integer: true, greater_than: 0 }
  validates :half, inclusion: { in: %w[top bottom] }
end
