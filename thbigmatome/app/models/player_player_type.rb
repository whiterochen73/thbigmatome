class PlayerPlayerType < ApplicationRecord
  belongs_to :player
  belongs_to :player_type

  validates :player_type_id, uniqueness: { scope: :player_id, message: :already_registered }
end
