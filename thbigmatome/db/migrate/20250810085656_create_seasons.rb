class CreateSeasons < ActiveRecord::Migration[8.0]
  def change
    create_table :seasons do |t|
      t.references :team, null: false, foreign_key: true

      t.string :name, null: false
      t.date :current_date, null: false
      t.references :key_player, foreign_key: { to_table: :team_memberships }
      t.string :team_type

      t.timestamps
    end
  end
end
