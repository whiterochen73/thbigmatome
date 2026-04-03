class RenameDefaultRoleColumns < ActiveRecord::Migration[8.0]
  def change
    rename_column :trait_definitions, :default_role, :typical_role
    rename_column :ability_definitions, :default_role, :typical_role
  end
end
