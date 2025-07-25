class CreatePitchingSkills < ActiveRecord::Migration[8.0]
  def change
    create_table :pitching_skills do |t|
      t.string :name
      t.text :description
      t.string :type

      t.timestamps
    end
    add_index :pitching_skills, :name, unique: true
  end
end
