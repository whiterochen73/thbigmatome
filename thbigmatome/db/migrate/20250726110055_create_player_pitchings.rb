class CreatePlayerPitchings < ActiveRecord::Migration[8.0]
  def change
    create_table :player_pitchings do |t|
      t.references :player, null: false, foreign_key: true
      t.boolean :is_relief_only, default: false
      t.integer :starter_stamina
      t.integer :relief_stamina
      t.references :pitching_skill, null: true, foreign_key: true

      t.timestamps
    end
  end
end
