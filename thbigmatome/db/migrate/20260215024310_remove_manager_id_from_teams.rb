class RemoveManagerIdFromTeams < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :teams, :managers, if_exists: true
    remove_index :teams, :manager_id, if_exists: true
    remove_column :teams, :manager_id, :bigint, null: false
  end
end
