class CreateLeagueMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :league_memberships do |t|
      t.references :league, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true

      t.timestamps
    end

    add_index :league_memberships, [:league_id, :team_id], unique: true
  end
end
