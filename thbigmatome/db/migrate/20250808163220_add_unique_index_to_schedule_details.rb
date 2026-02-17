class AddUniqueIndexToScheduleDetails < ActiveRecord::Migration[8.0]
  def change
    add_index :schedule_details, [:schedule_id, :date], unique: true
  end
end
