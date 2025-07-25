class CreateBattingSkills < ActiveRecord::Migration[7.1]
  def change
    create_table :batting_skills do |t|
      t.string :name, null: false
      t.text :description
      t.string :skill_type, null: false, default: "neutral"

      t.timestamps
    end
    add_index :batting_skills, :name, unique: true
  end
end
