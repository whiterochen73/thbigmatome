class CardSet < ApplicationRecord
  SERIES_BY_SET_TYPE = {
    "annual"     => "touhou",
    "hachinai61" => "hachinai",
    "pm2026"     => "original",
    "tamayomi2"  => "tamayomi"
  }.freeze

  has_many :player_cards, dependent: :destroy

  validates :year, presence: true, numericality: { only_integer: true }
  validates :name, presence: true
  validates :set_type, presence: true
  validates :year, uniqueness: { scope: :set_type }
end
