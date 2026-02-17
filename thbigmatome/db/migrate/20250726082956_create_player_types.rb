class CreatePlayerTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :player_types do |t|
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
    add_index :player_types, :name, unique: true
  end
end
