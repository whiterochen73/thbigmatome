class PlayerAbsence < ApplicationRecord
  belongs_to :team_membership
  belongs_to :season

  enum :absence_type, { injury: 0, suspension: 1, reconditioning: 2 }

  validates :absence_type, presence: true
  validates :start_date, presence: true
  validates :duration, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :duration_unit, presence: true, inclusion: { in: %w[days games] }

  # 離脱期間の終了日（排他的: この日には復帰可能）
  # days: start_date + duration日
  # games: start_date以降のN試合目の翌日（シーズンスケジュール参照）
  def effective_end_date
    if duration_unit == "days"
      start_date + duration.days
    else
      game_dates = season.season_schedules
        .where(date_type: %w[game_day interleague_game_day])
        .where("date >= ?", start_date)
        .order(:date)
        .limit(duration)
        .pluck(:date)

      return nil if game_dates.length < duration
      game_dates.last + 1.day
    end
  end
end
