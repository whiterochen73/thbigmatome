class AddDisplayNameToTeamMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :team_memberships, :display_name, :string
  end
end
