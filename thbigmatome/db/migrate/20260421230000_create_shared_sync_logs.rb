class CreateSharedSyncLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :shared_sync_logs do |t|
      t.string :resource_type, null: false
      t.integer :synced_count, default: 0
      t.string :status, null: false, default: "success"
      t.text :notes
      t.datetime :synced_at, null: false

      t.timestamps
    end

    add_index :shared_sync_logs, [ :resource_type, :synced_at ]
  end
end
