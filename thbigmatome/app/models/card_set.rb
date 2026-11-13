class CardSet < ApplicationRecord
  SERIES_BY_SET_TYPE = {
    "annual"     => "touhou",
    "hachinai61" => "hachinai",
    "pm2026"     => "original",
    "tamayomi2"  => "tamayomi"
  }.freeze

  # PM（オリジナル）は版を重ねるので（PM2026・PM2027・…、年の途中の追加も）、set_type の表に 1 行ずつ足さず「pm + 4 桁の年」で系列を決める。
  # 外の世界枠の判定は set_type の文字列でなく series（original）で見る
  ORIGINAL_SERIES = "original".freeze
  PM_SET_TYPE_PATTERN = /\Apm\d{4}\z/

  def self.series_for(set_type)
    SERIES_BY_SET_TYPE[set_type] || (ORIGINAL_SERIES if PM_SET_TYPE_PATTERN.match?(set_type.to_s))
  end

  has_many :player_cards, dependent: :destroy

  before_validation { self.series = self.class.series_for(set_type) if series.blank? }

  validates :year, presence: true, numericality: { only_integer: true }
  validates :name, presence: true
  validates :set_type, presence: true
  validates :year, uniqueness: { scope: :set_type }

  # 列の series が空の古い行（rake で作られた行など）でも set_type から引ける
  def effective_series
    series.presence || self.class.series_for(set_type)
  end
end
