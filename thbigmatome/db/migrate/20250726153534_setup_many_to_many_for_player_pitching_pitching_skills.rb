class SetupManyToManyForPlayerPitchingPitchingSkills < ActiveRecord::Migration[8.0]
  def change
    # Create the join table for player_pitchings and pitching_skills
    create_table :player_pitching_pitching_skills do |t|
      t.references :player_pitching, null: false, foreign_key: true
      t.references :pitching_skill, null: false, foreign_key: true

      t.timestamps
    end

    # Add a unique index to prevent a player_pitching from having the same skill twice
    add_index :player_pitching_pitching_skills, [:player_pitching_id, :pitching_skill_id], unique: true, name: 'idx_on_player_pitching_id_and_pitching_skill_id'

    # Remove the old foreign key column from the player_pitchings table
    remove_reference :player_pitchings, :pitching_skill, foreign_key: true, index: true
    add_reference :player_pitchings, :pitching_style, foreign_key: true, index: true
  end
end
