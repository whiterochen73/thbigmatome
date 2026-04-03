class CreateTraitDefinitions < ActiveRecord::Migration[8.0]
  def change
    create_table :trait_definitions do |t|
      t.string :name, null: false
      t.string :default_role
      t.text :description

      t.timestamps
    end

    add_index :trait_definitions, :name, unique: true
  end
end
