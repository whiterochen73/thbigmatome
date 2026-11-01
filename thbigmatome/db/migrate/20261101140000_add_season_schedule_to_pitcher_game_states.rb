# 登板（pitcher_game_states）を日程の行（season_schedules）に直接紐づける（cmd_1784 段3。設計書 §4.2・§5.2）。
# 値は rake season_records:link_pitcher_schedules が（チーム, 試合日）から引いて埋める。
# 列は null 可: 対応する日程の行が無い登板は紐づけず、一覧に出す。schedule_date（文字列）は互換と順序の比較のため残す。
# 日程の行が消えた時（シーズンの削除）は登板を消さず、紐づけだけを外す。
class AddSeasonScheduleToPitcherGameStates < ActiveRecord::Migration[8.1]
  def change
    add_reference :pitcher_game_states, :season_schedule, null: true, index: true,
                  foreign_key: { on_delete: :nullify }
  end
end
