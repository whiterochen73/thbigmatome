class AddSourceEventsToAtBatRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :at_bat_records, :source_events, :jsonb, default: [], null: false
  end
end
