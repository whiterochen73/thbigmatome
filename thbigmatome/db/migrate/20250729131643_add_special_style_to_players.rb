class AddSpecialStyleToPlayers < ActiveRecord::Migration[8.0]
  def change
    add_reference :players, :pinch_pitching_style, foreign_key: { to_table: :pitching_styles }, index: true
  end
end
