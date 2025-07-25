class CreateBiorhythms < ActiveRecord::Migration[7.1]
  def change
    create_table :biorhythms do |t|
      t.string :name, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false

      t.timestamps
    end
    add_index :biorhythms, :name, unique: true
  end
end
