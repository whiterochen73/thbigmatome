class CreateSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :schedules do |t|
      t.string :name
      t.date :start_date
      t.date :end_date
      t.date :effective_date

      t.timestamps
    end

    create_table :schedule_details do |t|
      t.references :schedule, null: false, foreign_key: true
      t.date :date
      t.string :date_type
      t.integer :priority

      t.timestamps
    end

  end
end
