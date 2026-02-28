class CreateGameRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :game_records do |t|
      t.references :team, null: false, foreign_key: true
      t.string :opponent_team_name
      t.date :game_date
      t.datetime :played_at
      t.string :stadium
      t.integer :score_home
      t.integer :score_away
      t.string :result
      t.string :status, default: "draft", null: false
      t.text :source_log
      t.string :parser_version
      t.datetime :parsed_at
      t.datetime :confirmed_at

      t.timestamps
    end

    add_index :game_records, :status
    add_index :game_records, :game_date
  end
end
