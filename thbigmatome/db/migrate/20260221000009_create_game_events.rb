class CreateGameEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :game_events do |t|
      t.references :game, null: false, foreign_key: true
      t.integer :seq, null: false
      t.string :event_type, null: false
      t.integer :inning, null: false
      t.string :half, null: false
      t.jsonb :details, default: {}, null: false

      t.timestamps
    end

    add_index :game_events, [ :game_id, :seq ], unique: true
    add_index :game_events, :event_type
    add_index :game_events, [ :game_id, :inning, :half ]
  end
end
