class AddStyleDescriptionToPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :pitching_style_description, :string
    add_column :players, :batting_style_description, :string
  end
end
