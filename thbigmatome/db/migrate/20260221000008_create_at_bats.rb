class CreateAtBats < ActiveRecord::Migration[8.0]
  def change
    create_table :at_bats do |t|
      t.references :game, null: false, foreign_key: true
      t.integer :seq, null: false
      t.integer :inning, null: false
      t.string :half, null: false
      t.integer :outs, null: false
      t.jsonb :runners, default: [], null: false
      t.references :batter, foreign_key: { to_table: :players }, null: false
      t.references :pitcher, foreign_key: { to_table: :players }, null: false
      t.references :pinch_hit_for, foreign_key: { to_table: :players }
      t.string :play_type, default: 'normal', null: false
      t.jsonb :rolls, default: [], null: false
      t.string :result_code, null: false
      t.integer :rbi, default: 0
      t.boolean :scored, default: false
      t.jsonb :runners_after, default: [], null: false
      t.integer :outs_after, null: false

      t.timestamps
    end

    add_index :at_bats, [ :game_id, :seq ], unique: true
    add_index :at_bats, [ :game_id, :inning, :half ]
  end
end
