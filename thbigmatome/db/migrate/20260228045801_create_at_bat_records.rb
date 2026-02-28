class CreateAtBatRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :at_bat_records do |t|
      t.references :game_record, null: false, foreign_key: true
      t.integer :inning
      t.string :half
      t.integer :ab_num
      t.string :pitcher_name
      t.string :pitcher_id
      t.string :batter_name
      t.string :batter_id
      t.integer :pitch_roll
      t.string :pitch_result
      t.integer :bat_roll
      t.string :bat_result
      t.string :result_code
      t.string :strategy
      t.jsonb :runners_before, default: {}
      t.jsonb :runners_after, default: {}
      t.integer :outs_before
      t.integer :outs_after
      t.integer :runs_scored, default: 0, null: false
      t.boolean :is_modified, default: false, null: false
      t.jsonb :modified_fields
      t.text :play_description
      t.jsonb :extra_data, default: {}

      t.timestamps
    end

    add_index :at_bat_records, [ :game_record_id, :ab_num ], unique: true
  end
end
