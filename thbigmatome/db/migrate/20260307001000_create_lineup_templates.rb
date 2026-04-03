class CreateLineupTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :lineup_templates do |t|
      t.references :team, null: false, foreign_key: true
      t.boolean :dh_enabled, null: false
      t.string :opponent_pitcher_hand, null: false

      t.timestamps
    end

    add_index :lineup_templates,
      [ :team_id, :dh_enabled, :opponent_pitcher_hand ],
      unique: true,
      name: "index_lineup_templates_uniqueness"
  end
end
