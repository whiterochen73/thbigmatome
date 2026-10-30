# 試合を行う実日付・大まかな開始時刻・開催球場（IRC のチャンネル）と、試合ログの原文。いずれも任意で、既存行は null のまま。
# stadium（文字列）はゲーム内の球場（甲子園など）で別物。ここの venue は IRC のどのチャンネルで試合をするか。
class AddRealGameInfoToSeasonSchedules < ActiveRecord::Migration[8.1]
  def change
    add_column :season_schedules, :real_date, :date
    add_column :season_schedules, :real_start_time, :string
    add_column :season_schedules, :venue, :string
    # 試合ログの原文。解析はせず保存するだけ（上限 1MB は model で検証）
    add_column :season_schedules, :game_log, :text
  end
end
