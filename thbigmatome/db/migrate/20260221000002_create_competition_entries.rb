class CreateCompetitionEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :competition_entries do |t|
      t.references :competition, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.references :base_team, foreign_key: { to_table: :teams }

      t.timestamps
    end

    add_index :competition_entries, [ :competition_id, :team_id ], unique: true
  end
end
