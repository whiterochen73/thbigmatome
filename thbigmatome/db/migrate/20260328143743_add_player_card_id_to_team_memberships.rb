class AddPlayerCardIdToTeamMemberships < ActiveRecord::Migration[8.1]
  def change
    add_reference :team_memberships, :player_card, null: true, foreign_key: true
  end
end
