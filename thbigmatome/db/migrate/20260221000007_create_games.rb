class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      t.references :competition, null: false, foreign_key: true
      t.references :home_team, foreign_key: { to_table: :teams }, null: false
      t.references :visitor_team, foreign_key: { to_table: :teams }, null: false
      t.references :stadium, null: false, foreign_key: { to_table: :stadiums }
      t.boolean :dh, default: false
      t.string :setting_date
      t.string :home_schedule_date
      t.string :visitor_schedule_date
      t.integer :home_game_number
      t.integer :visitor_game_number
      t.date :real_date
      t.integer :home_score
      t.integer :visitor_score
      t.string :status, default: 'draft', null: false
      t.string :source, default: 'live', null: false
      t.text :raw_log
      t.jsonb :roster_data, default: {}, null: false

      t.timestamps
    end

    add_index :games, :status
    add_index :games, [ :home_team_id, :visitor_team_id, :real_date ]
  end
end
