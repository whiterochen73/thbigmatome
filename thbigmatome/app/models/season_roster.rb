class SeasonRoster < ApplicationRecord
  # 1 日の中の時点の区分（設計書 §4.1）。順は pre_game < in_game < post_game
  # pre_game: 試合前の公示（試合のない日はその日の操作すべて）/ in_game: 試合そのもの / post_game: 試合後の操作
  PHASES = %w[pre_game in_game post_game].freeze
  DEFAULT_PHASE = "pre_game".freeze

  def self.phase_rank(phase)
    PHASES.index(phase) or raise ArgumentError, "invalid phase: #{phase.inspect}"
  end

  belongs_to :season
  belongs_to :team_membership
  belongs_to :recorded_by_user, class_name: "User", optional: true

  validates :squad, presence: true
  validates :registered_on, presence: true
  validates :phase, inclusion: { in: PHASES }
end
