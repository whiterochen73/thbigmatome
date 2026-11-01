# 種別 "no_game" の日程は、段4（cmd_1784）以降は新たに作れない（SeasonSchedule の検証）。
# 移行前のデータ（rake season_records:normalize_no_game_dates の対象）を作る spec 用に、検証を通さず保存する。
module LegacyNoGameHelper
  def legacy_no_game_schedule(**attrs)
    build(:season_schedule, **attrs, date_type: SeasonSchedule::NO_GAME_DATE_TYPE).tap { |schedule| schedule.save!(validate: false) }
  end
end

RSpec.configure { |config| config.include LegacyNoGameHelper }
