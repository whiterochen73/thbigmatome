class CreatePlayerAbsences < ActiveRecord::Migration[8.0]
  def change
    create_table :player_absences do |t|
      t.references :team_membership, null: false, foreign_key: true
      t.references :season, null: false, foreign_key: true
      t.integer :absence_type, null: false
      t.text :reason
      t.date :start_date, null: false
      t.integer :duration, null: false
      t.string :duration_unit, null: false

      t.timestamps
    end
  end
end
