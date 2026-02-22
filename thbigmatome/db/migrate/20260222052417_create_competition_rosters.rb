class CreateCompetitionRosters < ActiveRecord::Migration[8.1]
  def change
    create_table :competition_rosters do |t|
      t.references :competition_entry, null: false, foreign_key: true
      t.references :player_card, null: false, foreign_key: true
      t.integer :squad, null: false

      t.timestamps
    end

    add_index :competition_rosters, [ :competition_entry_id, :player_card_id ], unique: true,
              name: "index_competition_rosters_on_entry_and_card"
  end
end
