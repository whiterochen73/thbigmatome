export type SkillType = 'positive' | 'negative' | 'neutral'

export interface PitchingSkill {
  id: number
  name: string
  description: string | null
  skill_type: SkillType
}
