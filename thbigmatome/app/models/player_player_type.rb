class PlayerPlayerType < ApplicationRecord
  belongs_to :player
  belongs_to :player_type

  validates :player_type_id, uniqueness: { scope: :player_id, message: 'は既に登録されています' }
end