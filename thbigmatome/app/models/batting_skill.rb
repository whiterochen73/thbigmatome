class BattingSkill < ApplicationRecord
  # skill_typeをenumとして定義。DBには文字列として保存されます。
  enum :skill_type, { positive: 'positive', negative: 'negative', neutral: 'neutral' }

  validates :name, presence: true, uniqueness: true
  validates :skill_type, presence: true, inclusion: { in: skill_types.keys }
end