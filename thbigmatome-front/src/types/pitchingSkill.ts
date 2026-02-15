import type { SkillType } from './skill'

export interface PitchingSkill {
  id: number
  name: string
  description: string | null
  skill_type: SkillType
}
