class AtBatRecord < ApplicationRecord
  belongs_to :game_record

  VALID_HALVES = %w[top bottom].freeze
  VALID_STRATEGIES = %w[hitting bunt endrun steal intentional_walk].freeze

  validates :half, inclusion: { in: VALID_HALVES }, allow_nil: true
  validates :strategy, inclusion: { in: VALID_STRATEGIES }, allow_nil: true
  validates :runs_scored, numericality: { greater_than_or_equal_to: 0 }
  validates :ab_num, uniqueness: { scope: :game_record_id }, allow_nil: true
end
