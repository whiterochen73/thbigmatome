class AddUserIdToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :user_id, :bigint
  end
end
