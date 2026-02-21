class CreateCardSets < ActiveRecord::Migration[8.0]
  def change
    create_table :card_sets do |t|
      t.integer :year, null: false
      t.string :name, null: false
      t.string :set_type, default: 'annual', null: false

      t.timestamps
    end

    add_index :card_sets, [ :year, :set_type ]
  end
end
