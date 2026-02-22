class CardSet < ApplicationRecord
  has_many :player_cards, dependent: :destroy

  validates :year, presence: true, numericality: { only_integer: true }
  validates :name, presence: true
  validates :set_type, presence: true
  validates :year, uniqueness: { scope: :set_type }
end
