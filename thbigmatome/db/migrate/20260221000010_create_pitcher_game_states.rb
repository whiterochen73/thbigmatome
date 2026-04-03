class CreatePitcherGameStates < ActiveRecord::Migration[8.0]
  def change
    create_table :pitcher_game_states do |t|
      t.references :game, null: false, foreign_key: true
      t.references :pitcher, foreign_key: { to_table: :players }, null: false
      t.references :competition, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.string :role, null: false
      t.decimal :innings_pitched, precision: 5, scale: 1
      t.string :result_category
      t.integer :cumulative_innings, default: 0
      t.integer :fatigue_p_used, default: 0
      t.string :injury_check
      t.string :schedule_date

      t.timestamps
    end

    add_index :pitcher_game_states, [ :game_id, :pitcher_id ], unique: true
  end
end
