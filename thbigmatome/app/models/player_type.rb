class PlayerType < ApplicationRecord
  has_many :player_card_player_types, dependent: :restrict_with_error
  has_many :player_cards, through: :player_card_player_types

  validates :name, presence: true, uniqueness: true
end
