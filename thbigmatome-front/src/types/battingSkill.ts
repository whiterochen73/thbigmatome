export type SkillType = 'positive' | 'negative' | 'neutral'

export interface BattingSkill {
  id: number
  name: string
  description: string | null
  skill_type: SkillType
}