class CreateCompetitions < ActiveRecord::Migration[8.0]
  def change
    create_table :competitions do |t|
      t.string :name, null: false
      t.string :competition_type, null: false
      t.integer :year, null: false
      t.jsonb :rules, default: {}, null: false

      t.timestamps
    end

    add_index :competitions, [ :name, :year ], unique: true
    add_index :competitions, :competition_type
  end
end
