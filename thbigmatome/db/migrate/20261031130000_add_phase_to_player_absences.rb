# 離脱の「試合前 / 試合中」の区分（裁定 AMB-25）。日数の数え始めが区分で変わる。
#   pre_game: 試合日 D の当日から数える（D 〜 D+N−1 が離脱）
#   in_game : その試合には出ていて、翌日から数える（D+1 〜 D+N が離脱）
# 既存の離脱はすべて pre_game になり、振る舞いは変わらない。
class AddPhaseToPlayerAbsences < ActiveRecord::Migration[8.1]
  def change
    add_column :player_absences, :phase, :string, null: false, default: "pre_game"
  end
end
