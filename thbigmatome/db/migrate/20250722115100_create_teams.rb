class CreateTeams < ActiveRecord::Migration[8.0]
  def change
    create_table :teams do |t|
      t.string :name
      t.string :short_name
      t.boolean :is_active, default: true
      t.references :manager, null: false, foreign_key: true

      t.timestamps
    end
  end
end
