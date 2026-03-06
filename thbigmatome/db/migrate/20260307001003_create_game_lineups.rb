class CreateGameLineups < ActiveRecord::Migration[8.1]
  def change
    create_table :game_lineups do |t|
      t.references :team, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :lineup_data, null: false, default: {}

      t.timestamps
    end
  end
end
