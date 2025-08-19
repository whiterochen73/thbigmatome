class CreateSeasonSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :season_schedules do |t|
      t.references :season, null: false, foreign_key: true
      t.date :date, null: false
      t.string :date_type
      t.references :announced_starter, foreign_key: { to_table: :team_memberships }
      t.references :oppnent_team, foreign_key: { to_table: :teams }
      t.integer :game_number
      t.string :stadium
      t.string :home_away
      t.boolean :designated_hitter_enabled
      t.integer :score
      t.integer :oppnent_score
      t.references :winning_pitcher, foreign_key: { to_table: :players }
      t.references :losing_pitcher, foreign_key: { to_table: :players }
      t.references :save_pitcher, foreign_key: { to_table: :players }

      t.timestamps
    end
  end
end
