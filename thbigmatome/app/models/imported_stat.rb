class ImportedStat < ApplicationRecord
  belongs_to :player
  belongs_to :competition
  belongs_to :team

  STAT_TYPES = %w[batting pitching].freeze

  validates :stat_type, presence: true, inclusion: { in: STAT_TYPES }
  validates :player_id, uniqueness: { scope: [ :competition_id, :stat_type ] }
end
