class AddSeriesToCardSets < ActiveRecord::Migration[8.1]
  SERIES_BY_SET_TYPE = {
    "annual"      => "touhou",
    "hachinai61"  => "hachinai",
    "pm2026"      => "original",
    "tamayomi2"   => "tamayomi"
  }.freeze

  def up
    add_column :card_sets, :series, :string

    # Backfill existing card_sets from set_type
    CardSet.find_each do |cs|
      series = SERIES_BY_SET_TYPE[cs.set_type]
      cs.update_column(:series, series) if series.present?
    end
  end

  def down
    remove_column :card_sets, :series
  end
end
