class AddExcludedFromTeamTotalToTeamMemberships < ActiveRecord::Migration[8.0]
  def change
    add_column :team_memberships, :excluded_from_team_total, :boolean, default: false, null: false
  end
end
