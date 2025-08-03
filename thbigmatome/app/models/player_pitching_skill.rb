class PlayerPitchingSkill < ApplicationRecord
  belongs_to :player
  belongs_to :pitching_skill

  validates :pitching_skill_id, uniqueness: { scope: :player_id, message: 'は既に登録されています' }
end