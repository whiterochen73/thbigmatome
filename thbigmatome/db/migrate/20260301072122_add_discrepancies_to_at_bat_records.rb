class AddDiscrepanciesToAtBatRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :at_bat_records, :discrepancies, :jsonb, default: [], null: false
  end
end
