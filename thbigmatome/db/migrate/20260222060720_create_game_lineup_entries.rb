class CreateGameLineupEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :game_lineup_entries do |t|
      t.bigint :game_id, null: false
      t.bigint :player_card_id, null: false
      t.integer :role, null: false
      t.integer :batting_order
      t.string :position
      t.boolean :is_dh_pitcher, default: false, null: false
      t.boolean :is_reliever, default: false, null: false

      t.timestamps
    end

    add_index :game_lineup_entries, :game_id
    add_index :game_lineup_entries, :player_card_id
    add_index :game_lineup_entries, [ :game_id, :player_card_id ], unique: true
  end
end
