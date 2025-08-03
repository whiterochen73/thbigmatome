class PlayerBiorhythm < ApplicationRecord
  belongs_to :player
  belongs_to :biorhythm

  validates :biorhythm_id, uniqueness: { scope: :player_id, message: 'は既に登録されています' }
end