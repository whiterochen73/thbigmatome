class CreateCosts < ActiveRecord::Migration[8.0]
  def change
    create_table :costs do |t|
      t.string :name
      t.date :start_date
      t.date :end_date

      t.timestamps
    end

    create_table :cost_players do |t|
      t.references :cost, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true

      t.integer :normal_cost
      t.integer :relief_only_cost
      t.integer :pitcher_only_cost
      t.integer :fielder_only_cost
      t.integer :two_way_cost

      t.timestamps
    end

    add_index :cost_players, [:cost_id, :player_id]
  end
end
