class AddConstraintsToBattingAndPitchingStyles < ActiveRecord::Migration[8.0]
  def change
    change_column_null :batting_styles, :name, false
    add_index :batting_styles, :name, unique: true

    change_column_null :pitching_styles, :name, false
    add_index :pitching_styles, :name, unique: true
  end
end
