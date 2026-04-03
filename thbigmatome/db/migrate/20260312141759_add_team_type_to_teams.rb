class AddTeamTypeToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :team_type, :string, null: false, default: "normal"
    add_index :teams, :team_type
  end
end
