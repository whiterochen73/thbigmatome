class CreatePitchingStyles < ActiveRecord::Migration[8.0]
  def change
    create_table :pitching_styles do |t|
      t.string :name
      t.string :description

      t.timestamps
    end
  end
end
