class RemovePlayerStyleFkColumns < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :players, :pitching_styles, column: :catcher_pitching_style_id
    remove_foreign_key :players, :pitching_styles, column: :pinch_pitching_style_id
    remove_column :players, :catcher_pitching_style_id, :bigint
    remove_column :players, :pinch_pitching_style_id, :bigint
  end
end
