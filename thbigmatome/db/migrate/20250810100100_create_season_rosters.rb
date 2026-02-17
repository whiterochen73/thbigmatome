class CreateSeasonRosters < ActiveRecord::Migration[7.1]
  def change
    create_table :season_rosters do |t|
      t.references :season, null: false, foreign_key: true
      t.references :team_membership, null: false, foreign_key: true
      t.string :squad, default: "second", null: false
      t.date :registered_on, null: false

      t.timestamps
    end
  end
end
