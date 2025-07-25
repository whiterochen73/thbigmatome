class CreateBattingStyles < ActiveRecord::Migration[8.0]
  def change
    create_table :batting_styles do |t|
      t.string :name
      t.string :description

      t.timestamps
    end
  end
end
