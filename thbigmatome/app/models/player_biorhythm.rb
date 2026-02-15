class PlayerBiorhythm < ApplicationRecord
  belongs_to :player
  belongs_to :biorhythm

  validates :biorhythm_id, uniqueness: { scope: :player_id, message: :already_registered }
end
