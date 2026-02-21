class CreatePlayerCards < ActiveRecord::Migration[8.0]
  def change
    create_table :player_cards do |t|
      t.references :card_set, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.integer :speed
      t.integer :bunt
      t.integer :steal_start
      t.integer :steal_end
      t.integer :injury_rate
      t.boolean :is_pitcher, default: false
      t.boolean :is_relief_only, default: false
      t.integer :starter_stamina
      t.integer :relief_stamina
      t.references :batting_style, foreign_key: true
      t.string :batting_style_description
      t.references :pitching_style, foreign_key: { to_table: :pitching_styles }
      t.references :pinch_pitching_style, foreign_key: { to_table: :pitching_styles }
      t.references :catcher_pitching_style, foreign_key: { to_table: :pitching_styles }
      t.string :pitching_style_description
      t.string :defense_p
      t.integer :throwing_c
      t.string :defense_c
      t.string :special_defense_c
      t.integer :special_throwing_c
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
      t.jsonb :batting_table, default: {}, null: false
      t.jsonb :pitching_table, default: {}, null: false
      t.jsonb :abilities, default: {}, null: false
      t.string :card_image_path

      t.timestamps
    end

    add_index :player_cards, [ :card_set_id, :player_id ], unique: true
  end
end
