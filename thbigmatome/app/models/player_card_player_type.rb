class PlayerCardPlayerType < ApplicationRecord
  belongs_to :player_card
  belongs_to :player_type

  validates :player_card_id, uniqueness: { scope: :player_type_id }
end
