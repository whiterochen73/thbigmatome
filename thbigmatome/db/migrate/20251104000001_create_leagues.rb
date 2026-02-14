class CreateLeagues < ActiveRecord::Migration[8.0]
  def change
    create_table :leagues do |t|
      t.string :name, null: false
      t.integer :num_teams, default: 6, null: false
      t.integer :num_games, default: 30, null: false
      t.boolean :active, default: false, null: false

      t.timestamps
    end
  end
end
