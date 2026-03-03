class AddAdoptedValueToAtBatRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :at_bat_records, :gsm_value, :jsonb, default: {}
    add_column :at_bat_records, :adopted_value, :jsonb, default: {}
  end
end
