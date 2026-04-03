class AddStatusToAtBats < ActiveRecord::Migration[8.1]
  def change
    add_column :at_bats, :status, :integer, default: 0, null: false
    add_index :at_bats, [ :game_id, :status ]
  end
end
