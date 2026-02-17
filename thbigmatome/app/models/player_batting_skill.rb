class PlayerBattingSkill < ApplicationRecord
  belongs_to :player
  belongs_to :batting_skill

  validates :batting_skill_id, uniqueness: { scope: :player_id, message: :already_registered }
end
