class AddRoleToManagers < ActiveRecord::Migration[7.0]
  def change
    add_column :managers, :role, :integer, default: 0, null: false
  end
end
