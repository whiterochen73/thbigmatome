import type { SkillType } from './skill'

export interface BattingSkill {
  id: number
  name: string
  description: string | null
  skill_type: SkillType
}
