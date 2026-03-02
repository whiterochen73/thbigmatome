class AddReviewFieldsToAtBatRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :at_bat_records, :is_reviewed, :boolean, default: false, null: false
    add_column :at_bat_records, :review_notes, :text
  end
end
