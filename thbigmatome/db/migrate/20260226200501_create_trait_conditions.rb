class CreateTraitConditions < ActiveRecord::Migration[8.0]
  def change
    create_table :trait_conditions do |t|
      t.string :name, null: false
      t.text :description

      t.timestamps
    end

    add_index :trait_conditions, :name, unique: true
  end
end
