# 昇降格の変更記録に「同じ日の中の試合前・試合後」の区分と、記録した利用者を足す（cmd_1784 段1）。
# 設計: context/thbig-dugout-season-record-restructure-design.md §4.1・§4.2。
# 既存の記録は既定の pre_game（試合前の公示）として読む。列の追加だけで、既存行は書き換えない。
class AddPhaseAndRecorderToSeasonRosters < ActiveRecord::Migration[8.1]
  def change
    add_column :season_rosters, :phase, :string, default: "pre_game", null: false
    add_reference :season_rosters, :recorded_by_user, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
    add_check_constraint :season_rosters, "phase IN ('pre_game', 'in_game', 'post_game')", name: "season_rosters_phase_check"
  end
end
