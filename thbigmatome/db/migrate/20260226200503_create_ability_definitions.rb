class CreateAbilityDefinitions < ActiveRecord::Migration[8.0]
  def change
    create_table :ability_definitions do |t|
      t.string :name, null: false
      t.string :default_role
      t.text :effect_description

      t.timestamps
    end

    add_index :ability_definitions, :name, unique: true
  end
end
