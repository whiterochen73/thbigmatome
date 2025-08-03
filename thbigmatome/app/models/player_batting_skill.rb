class PlayerBattingSkill < ApplicationRecord
  belongs_to :player
  belongs_to :batting_skill

  validates :batting_skill_id, uniqueness: { scope: :player_id, message: 'は既に登録されています' }
end