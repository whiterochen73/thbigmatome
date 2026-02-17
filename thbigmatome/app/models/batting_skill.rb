class BattingSkill < ApplicationRecord
  # skill_typeをenumとして定義。DBには文字列として保存されます。
  enum :skill_type, { positive: 'positive', negative: 'negative', neutral: 'neutral' }

  has_many :player_batting_skills, dependent: :restrict_with_error
  has_many :players, through: :player_batting_skills

  validates :name, presence: true, uniqueness: true
  validates :skill_type, presence: true, inclusion: { in: skill_types.keys }
end