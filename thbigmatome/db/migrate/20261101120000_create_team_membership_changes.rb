# チーム編成（登録・契約・放出）の変更記録の表と、team_memberships の「在籍」の写しを足す（cmd_1784 段2）。
# 設計: context/thbig-dugout-season-record-restructure-design.md §4.2（team_membership_changes）・§5.2 段2。
#
# - 変更記録は差分ではなく「変更後の値を丸ごと」持つ。どの時点も 1 行で状態が決まる。
# - kind: join（登録。再登録を含む）/ contract（契約・カード・コスト除外・表示名の変更）/ release（放出）。
# - team_memberships.on_team は「最新の状態」の写し（放出されていれば false）。放出しても行は消さない（登板・離脱・昇降格の記録が指す先）。
# 列と表の追加だけ。既存行は書き換えない（初期の join 記録は rake season_records:backfill_membership_changes が作る）。
class CreateTeamMembershipChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :team_membership_changes do |t|
      t.references :team_membership, null: false, foreign_key: true
      t.references :season, null: false, foreign_key: true
      t.date :effective_on, null: false
      t.string :phase, null: false, default: "pre_game"
      t.string :kind, null: false
      t.string :selected_cost_type, null: false
      t.references :player_card, null: true, foreign_key: true
      t.boolean :excluded_from_team_total, null: false, default: false
      t.string :display_name
      t.references :recorded_by_user, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end

    add_index :team_membership_changes, [ :team_membership_id, :effective_on ], name: "index_team_membership_changes_on_tm_and_date"
    add_check_constraint :team_membership_changes, "phase IN ('pre_game', 'in_game', 'post_game')", name: "team_membership_changes_phase_check"
    add_check_constraint :team_membership_changes, "kind IN ('join', 'contract', 'release')", name: "team_membership_changes_kind_check"

    add_column :team_memberships, :on_team, :boolean, null: false, default: true
  end
end
