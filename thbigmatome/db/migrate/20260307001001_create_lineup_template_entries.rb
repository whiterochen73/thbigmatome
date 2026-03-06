class CreateLineupTemplateEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :lineup_template_entries do |t|
      t.references :lineup_template, null: false, foreign_key: true
      t.integer :batting_order, null: false
      t.references :player, null: false, foreign_key: true
      t.string :position, null: false

      t.timestamps
    end

    add_index :lineup_template_entries,
      [ :lineup_template_id, :batting_order ],
      unique: true,
      name: "index_lineup_template_entries_on_template_and_order"
  end
end
