class AddStatColumnsToGameRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :game_records, :batting_stats, :jsonb
    add_column :game_records, :pitching_stats, :jsonb
  end
end
