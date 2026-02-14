class CreateLeaguePoolPlayers < ActiveRecord::Migration[7.0]
  def change
    create_table :league_pool_players do |t|
      t.references :league_season, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true

      t.timestamps
    end
  end
end
