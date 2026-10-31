# 現在日は日程の結果から導かれる（SeasonCurrentRange。cmd_1784 段2b）。
# 「現在日 = date」の状態を作る spec 用のヘルパー。
#   - date より前の最後の日程に結果（1-0）を入れる。無ければ前日に予備日を足して結果を入れる
#   - date に試合日（playoff_day）を足す。1軍人数の検査（RosterConstraintChecker）は game_day だけを試合日として見るので、
#     既存の spec の「試合の無い日」の前提を崩さない
module CurrentDateHelper
  def pin_current_date(season, date)
    date = date.to_date
    previous = season.season_schedules.where("date < ?", date).order(:date).last
    previous ||= SeasonSchedule.create!(season: season, date: date - 1, date_type: "reserve_day")
    previous.update!(score: 1, opponent_score: 0)
    day = season.season_schedules.find_by(date: date)
    if day.nil?
      SeasonSchedule.create!(season: season, date: date, date_type: "playoff_day")
    elsif !SeasonCurrentRange::GAME_DATE_TYPES.include?(day.date_type)
      day.update!(date_type: "playoff_day")
    end
    season.current_date
  end
end

RSpec.configure { |config| config.include CurrentDateHelper }
