# 日程マスタ（schedule_details）の完全性の検算（AMB-11。Operator 裁定 2026-09-12「通常 143 試合という総数は、日程の完全性チェック（試合日が 143 あるか）に使える」。
# THBIG ルールブック 04-game-setup §4.5）。レギュラー（通常・交流戦）の試合日の数が 143 かを数える。プレーオフ日は数えない。
#
# cmd_1802 の調査で、ペナント日程表が作成時（2025-08-09）から 144 日だったと分かった（この検算が無く、だれも総数を数えていなかった）。
# マスタが入る経路（seed・設定画面の upsert_all）の後で呼ぶ。
#   - seed（db/seeds.rb）: 合わなければ例外で止める（定数のデータなので、合わないのは書き間違い）
#   - 設定画面の upsert_all: 止めず、応答に warnings を付ける（日程表は 143 でないものも作れる。画面は応答の本文を読まない）
class ScheduleMasterCheck
  EXPECTED_REGULAR_GAME_DAYS = 143

  class Mismatch < StandardError; end

  def self.regular_game_days(schedule)
    schedule.schedule_details.where(date_type: SeasonGameProgress::REGULAR_DATE_TYPES).count
  end

  # 合っていれば空、合わなければ説明の文字列を 1 つ入れた配列
  def self.warnings(schedule)
    count = regular_game_days(schedule)
    return [] if count == EXPECTED_REGULAR_GAME_DAYS

    [ "日程表「#{schedule.name}」のレギュラー（通常・交流戦）の試合日が #{count} 日です（規定は #{EXPECTED_REGULAR_GAME_DAYS} 日。AMB-11）。日付の種類を見直してください" ]
  end

  def self.verify!(schedule)
    messages = warnings(schedule)
    raise Mismatch, messages.first if messages.any?
  end
end
