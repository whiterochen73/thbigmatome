class CreateLeagueSeasons < ActiveRecord::Migration[7.0]
  def change
    create_table :league_seasons do |t|
      t.references :league, null: false, foreign_key: true
      t.string :name, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end
  end
end
