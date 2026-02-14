class CreateTeamManagers < ActiveRecord::Migration[7.0]
  def change
    create_table :team_managers do |t|
      t.references :team, null: false, foreign_key: true
      t.references :manager, null: false, foreign_key: true
      t.integer :role, default: 0, null: false

      t.timestamps
    end
  end
end
