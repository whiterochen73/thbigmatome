class SetupManyToManyForPlayerBattingSkills < ActiveRecord::Migration[8.0]
  def change
    # Create the join table for players and batting_skills
    create_table :player_batting_skills do |t|
      t.references :player, null: false, foreign_key: true
      t.references :batting_skill, null: false, foreign_key: true

      t.timestamps
    end

    # Add a unique index to prevent a player from having the same skill twice
    add_index :player_batting_skills, [:player_id, :batting_skill_id], unique: true

    # Remove the old foreign key column from the players table
    remove_reference :players, :batting_skill, foreign_key: true, index: true
    # Remove the old foreign key column from the players table
    add_reference :players, :batting_style, foreign_key: true, index: true
  end
end
