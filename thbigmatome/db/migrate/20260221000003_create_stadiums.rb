class CreateStadiums < ActiveRecord::Migration[8.0]
  def change
    create_table :stadiums do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.jsonb :up_table_ids, default: [], null: false
      t.boolean :indoor, default: false, null: false

      t.timestamps
    end

    add_index :stadiums, :code, unique: true
    add_index :stadiums, :name, unique: true
  end
end
