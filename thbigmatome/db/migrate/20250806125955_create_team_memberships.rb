class CreateTeamMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :team_memberships do |t|
      t.references :team, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.string :squad, null: false, default: 'second'
      t.string :selected_cost_type, null: false, default: 'normal_cost'

      t.timestamps
    end

    add_index :team_memberships, [:team_id, :player_id], unique: true
  end
end