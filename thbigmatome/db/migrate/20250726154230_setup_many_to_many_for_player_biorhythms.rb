class SetupManyToManyForPlayerBiorhythms < ActiveRecord::Migration[8.0]
  def change
    create_table :player_biorhythms do |t|
      t.references :player, null: false, foreign_key: true
      t.references :biorhythm, null: false, foreign_key: true

      t.timestamps
    end

    add_index :player_biorhythms, [:player_id, :biorhythm_id], unique: true
  end
end
