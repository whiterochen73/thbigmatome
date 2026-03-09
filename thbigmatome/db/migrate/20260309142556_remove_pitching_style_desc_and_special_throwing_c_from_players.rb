class RemovePitchingStyleDescAndSpecialThrowingCFromPlayers < ActiveRecord::Migration[8.1]
  def change
    remove_column :players, :pitching_style_description, :string
    remove_column :players, :special_throwing_c, :string
  end
end
