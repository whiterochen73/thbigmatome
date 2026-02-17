class CreateLeagueGames < ActiveRecord::Migration[7.0]
  def change
    create_table :league_games do |t|
      t.references :league_season, null: false, foreign_key: true
      t.references :home_team, null: false, foreign_key: { to_table: :teams }
      t.references :away_team, null: false, foreign_key: { to_table: :teams }
      t.date :game_date, null: false
      t.integer :game_number, null: false

      t.timestamps
    end
  end
end
