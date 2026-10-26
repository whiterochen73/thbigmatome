# ノーゲーム（試合が成立しなかった試合）の印。投手疲労では KO・ノーゲーム表（rulebook 08 §8.3.1）を使い、
# 成績は算入しない（台帳 D-11）。得点では表せないので、試合概要に持つ（cmd_1775 第3段 E12）。
class AddNoGameToSeasonSchedules < ActiveRecord::Migration[8.1]
  def change
    add_column :season_schedules, :no_game, :boolean, default: false, null: false
  end
end
