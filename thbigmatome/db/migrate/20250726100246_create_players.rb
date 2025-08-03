class CreatePlayers < ActiveRecord::Migration[8.0]
  def change
    create_table :players do |t|
      t.string :name, null: false
      t.string :short_name
      t.string :number, null: false
      t.string :position
      t.string :throwing_hand
      t.string :batting_hand
      t.integer :speed
      t.integer :bunt
      t.integer :steal_start
      t.integer :steal_end
      t.integer :injury_rate
      t.string :defense_p
      t.string :defense_c
      t.integer :throwing_c
      t.string :defense_1b
      t.string :defense_2b
      t.string :defense_3b
      t.string :defense_ss
      t.string :defense_of
      t.string :throwing_of
      t.string :defense_lf
      t.string :throwing_lf
      t.string :defense_cf
      t.string :throwing_cf
      t.string :defense_rf
      t.string :throwing_rf
      t.references :batting_skill, null: true, foreign_key: true

      t.timestamps
    end
  end
end
