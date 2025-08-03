class AddCatchersToPlayers < ActiveRecord::Migration[8.0]
  def change
    create_table :catchers_players, id: false do |t|
      t.references :player, foreign_key: true
      t.references :catcher, foreign_key: { to_table: :players }
    end
    add_index :catchers_players, [:player_id, :catcher_id], unique: true

    add_reference :players, :catcher_pitching_style, foreign_key: { to_table: :pitching_styles }, index: true
  end
end
