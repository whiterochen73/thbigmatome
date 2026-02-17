class DropPlayerPitchingsTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :player_pitching_pitching_skills
    drop_table :player_pitchings
  end
end
