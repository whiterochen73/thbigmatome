class CreateSquadTextSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :squad_text_settings do |t|
      t.references :team, null: false, foreign_key: true, index: { unique: true }
      t.string :position_format, default: "english"
      t.string :handedness_format, default: "alphabet"
      t.string :date_format, default: "absolute"
      t.string :section_header_format, default: "bracket"
      t.boolean :show_number_prefix, default: true
      t.jsonb :batting_stats_config, default: {}
      t.jsonb :pitching_stats_config, default: {}

      t.timestamps
    end
  end
end
