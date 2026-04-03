class CreateImportedStats < ActiveRecord::Migration[8.0]
  def change
    create_table :imported_stats do |t|
      t.references :player, null: false, foreign_key: true
      t.references :competition, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.string :stat_type, null: false
      t.string :as_of_date
      t.integer :as_of_game_number
      t.jsonb :stats, default: {}, null: false

      t.timestamps
    end

    add_index :imported_stats, [ :player_id, :competition_id, :stat_type ], unique: true
  end
end
