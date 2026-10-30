class PlayerAbsence < ApplicationRecord
  belongs_to :team_membership
  belongs_to :season

  enum :absence_type, { injury: 0, suspension: 1, reconditioning: 2 }

  # 離脱を記録した時点が、その試合日の試合前か試合中か（裁定 AMB-25）。start_date はどちらも試合日 D。
  #   pre_game: D の当日から数える。N 日なら D 〜 D+N−1 が離脱で D+N に復帰
  #   in_game : D の試合には出ている。翌日から数える。N 日なら D+1 〜 D+N が離脱で D+N+1 に復帰
  PHASES = %w[pre_game in_game].freeze

  validates :absence_type, presence: true
  validates :start_date, presence: true
  validates :duration, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :duration_unit, presence: true, inclusion: { in: %w[days games] }
  validates :phase, inclusion: { in: PHASES }

  def in_game?
    phase == "in_game"
  end

  # 離脱が始まる最初の日（この日から離脱中）。試合中の離脱は start_date の翌日
  def effective_start_date
    in_game? ? start_date + 1.day : start_date
  end

  # 離脱期間の終了日（排他的: この日には復帰可能）
  # days: effective_start_date + duration日
  # games: effective_start_date 以降のN試合目の翌日（シーズンスケジュール参照）
  #   pre_game は start_date 当日の試合を数え、in_game は start_date より後の試合から数える
  def effective_end_date
    if duration_unit == "days"
      effective_start_date + duration.days
    else
      game_dates = season.season_schedules
        .where(date_type: %w[game_day interleague_game_day])
        .where("date >= ?", effective_start_date)
        .order(:date)
        .limit(duration)
        .pluck(:date)

      return nil if game_dates.length < duration
      game_dates.last + 1.day
    end
  end

  # date の日に離脱中か。呼び出し側はこれを使う（start_date を直接比べない）。
  # end が nil（試合数の離脱でスケジュールが足りない）は復帰日が未定 = 離脱が続いているとみなす。
  def active_on?(date)
    date = date.to_date
    return false if date < effective_start_date

    end_date = effective_end_date
    end_date.nil? || date < end_date
  end

  # date 時点の「残りの離脱の数え始め」。in_game は start_date 当日（試合に出た日）を離脱に数えないため、
  # その日に見ても翌日から数える。pre_game は date そのまま（区分を足す前の振る舞いを変えない）。
  def counting_from(date)
    date = date.to_date
    in_game? ? [ date, effective_start_date ].max : date
  end

  # date 時点の残り日数（復帰日までの日数）。復帰日が未定なら nil
  def remaining_days_on(date)
    end_date = effective_end_date
    return nil unless end_date

    (end_date.to_date - counting_from(date)).to_i
  end
end
